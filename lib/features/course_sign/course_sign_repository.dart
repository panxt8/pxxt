import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../core/location/baidu_location_service.dart';
import '../../core/models/active_task.dart';
import '../../core/models/sign_flow_result.dart';
import '../../core/models/sign_session.dart';
import '../../core/models/sign_type_info.dart';
import '../../core/network/app_urls.dart';
import '../../core/session/sign_session_provider.dart';
import '../../core/utils/captcha_handler.dart';

part 'course_sign_repository_helpers.dart';

class CourseSignRepository with _CourseSignRepositoryHelpers {
  CourseSignRepository(this._dio, this._sessionProvider);

  @override
  final Dio _dio;
  final SignSessionProvider _sessionProvider;
  @override
  final Map<String, _ActiveMetaCacheEntry> _activeMetaCache = {};
  static const _forceCookieHeader = 'x-force-cookie';
  static const Duration _activeMetaTtl = Duration(seconds: 25);

  static const _signHeaders = {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 14_2_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 com.ssreader.ChaoXingStudy/ChaoXingStudy_3_4.8_ios_phone_202012052220_56 (@Kalimdor)_12787186548451577248',
  };
  static final RegExp _distanceRegExp = RegExp(
    r'(?:签到地点|地点)\s*([0-9]+(?:\.[0-9]+)?)米',
  );
  static final RegExp _allDigitsRegExp = RegExp(r'^\d+$');
  static final RegExp _aidInPayloadRegExp = RegExp(r'aid=([^&\s]+)');
  static const String _captchaId = 'Qt9FIw9o4pwRjOyqM6yizZBh682qN2TU';

  Future<List<ActiveTask>> loadTasks({
    required String courseId,
    required String classId,
    required String uid,
    required String cpi,
  }) async {
    final response = await _dio.get<dynamic>(
      AppUrls.activeTaskList(courseId, classId, uid, cpi),
      options: Options(headers: _headers(null)),
    );
    final data = _asMap(response.data);
    final list = data['activeList'];
    if (list is! List) return const [];
    return list.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return ActiveTask(
        id: map['id']?.toString() ?? '',
        name: map['nameOne']?.toString() ?? '-',
        status: map['status']?.toString() ?? '',
        type: map['activeType']?.toString() ?? '',
        preSignUrl: map['url']?.toString() ?? '',
      );
    }).toList();
  }

  Future<SignTypeInfo> fetchSignType(String activeId) async {
    final response = await _dio.get<String>(
      AppUrls.signType(activeId),
      options: Options(headers: _headers(null)),
    );
    final html = response.data ?? '';
    return SignTypeInfo(
      activeId: _matchValue(html, 'id'),
      otherId: _matchValue(html, 'otherId'),
      ifPhoto: _matchValue(html, 'ifPhoto'),
    );
  }

  SignSession resolveMainSession({required String uid, required String fid}) {
    final stored = _sessionProvider.getMainSession();
    if (stored == null) {
      return SignSession(cookie: '', uid: uid, fid: fid, username: 'main');
    }
    return SignSession(
      cookie: stored.cookie,
      uid: stored.uid.isNotEmpty ? stored.uid : uid,
      fid: stored.fid.isNotEmpty ? stored.fid : fid,
      username: stored.username,
    );
  }

  Future<SignSession?> resolveLinkedSession({
    required String username,
    required String password,
  }) {
    return _sessionProvider.resolveLinkedSession(
      username: username,
      password: password,
    );
  }

  Future<void> prepareSessionForSign({
    required SignSession session,
    required String aid,
    required String preSignUrl,
  }) async {
    final cookie = session.cookie.isEmpty ? null : session.cookie;
    await _analysisWithCookie(aid, cookie);
    final url = session.uid.isEmpty
        ? preSignUrl
        : _setUidInUrl(preSignUrl, session.uid);
    await _preSignWithCookie(url, cookie);
  }

  Future<String?> _solveValidateIfNeeded({
    required bool needVCode,
    required String? cookie,
    required String referer,
    String accountUid = 'main',
  }) async {
    if (!needVCode) return '';
    final validate = await _solveSlideCaptcha(
      cookie: cookie,
      referer: referer,
      accountUid: accountUid,
    );
    if (validate.isEmpty) return null;
    return validate;
  }

  Future<QrSignData> prepareQrSign({
    required ActiveTask task,
    required String qrCodeRaw,
    required String captchaReferer,
    String? preSignHtml,
    required String? cookie,
    String? preSignUid,
  }) async {
    final qrCodePayload = _extractQrCodePayload(qrCodeRaw);
    if (qrCodePayload.isEmpty) {
      throw StateError('二维码内容无效');
    }
    final payloadCandidates = _buildQrPayloadCandidates(qrCodePayload);
    final analysisAid = payloadCandidates
        .map(_extractAnalysisAid)
        .firstWhere((a) => a.isNotEmpty, orElse: () => '');
    if (analysisAid.isEmpty) {
      throw StateError('二维码内容无效');
    }

    await _analysisWithCookie(analysisAid, cookie);
    final basePreSignUrl = (preSignUid == null || preSignUid.isEmpty)
        ? task.preSignUrl
        : _setUidInUrl(task.preSignUrl, preSignUid);
    final signPreHtml = (preSignHtml != null && preSignHtml.isNotEmpty)
        ? preSignHtml
        : await _preSignWithCookie(basePreSignUrl, cookie);

    final locationMeta = await _fetchLocationSignMetaWithCookie(
      analysisAid,
      cookie: cookie,
      preSignHtml: signPreHtml,
    );

    var locationPayload = '';
    if (locationMeta.allowDirectSign) {
      locationPayload = await _buildLocationPayload(
        address: locationMeta.locationText,
      );
    }
    return QrSignData(
      analysisAid: analysisAid,
      payloadCandidates: payloadCandidates,
      includeLocation: locationMeta.allowDirectSign,
      locationPayload: locationPayload,
      needVCode: locationMeta.needVCode,
      captchaReferer: captchaReferer,
      preSignUrl: task.preSignUrl,
    );
  }

  Future<LocationSignData> prepareCurrentLocationSign({
    required ActiveTask task,
    required String aid,
    required String fallbackAddress,
    required String captchaReferer,
    required String? cookie,
    String? preSignUid,
  }) async {
    return _prepareLocationSign(
      task: task,
      aid: aid,
      fallbackAddress: fallbackAddress,
      captchaReferer: captchaReferer,
      cookie: cookie,
      preSignUid: preSignUid,
    );
  }

  Future<LocationSignData> prepareSelectedLocationSign({
    required ActiveTask task,
    required String aid,
    required double latitude,
    required double longitude,
    required String fallbackAddress,
    required String captchaReferer,
    required String? cookie,
    String? preSignUid,
  }) async {
    return _prepareLocationSign(
      task: task,
      aid: aid,
      fallbackAddress: fallbackAddress,
      captchaReferer: captchaReferer,
      cookie: cookie,
      preSignUid: preSignUid,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<LocationSignData> _prepareLocationSign({
    required ActiveTask task,
    required String aid,
    required String fallbackAddress,
    required String captchaReferer,
    required String? cookie,
    String? preSignUid,
    double? latitude,
    double? longitude,
  }) async {
    await _analysisWithCookie(aid, cookie);
    final preSignUrl = (preSignUid == null || preSignUid.isEmpty)
        ? task.preSignUrl
        : _setUidInUrl(task.preSignUrl, preSignUid);
    final preSignHtml = await _preSignWithCookie(preSignUrl, cookie);
    final meta = await _fetchLocationSignMetaWithCookie(
      aid,
      cookie: cookie,
      preSignHtml: preSignHtml,
    );

    final submitLat = latitude;
    final submitLon = longitude;
    final resolvedPoint = (submitLat != null && submitLon != null)
        ? null
        : await _getCurrentPosition();
    final effectiveLat = submitLat ?? resolvedPoint!.latitude;
    final effectiveLon = submitLon ?? resolvedPoint!.longitude;
    final resolvedAddress = _resolveAddress(
      locationText: meta.locationText,
      fallbackAddress: fallbackAddress,
    );
    return LocationSignData(
      aid: aid,
      latitude: effectiveLat,
      longitude: effectiveLon,
      address: resolvedAddress,
      needVCode: meta.needVCode,
      captchaReferer: captchaReferer,
      preSignUrl: task.preSignUrl,
    );
  }

  Future<SignFlowResult> submitQrSign({
    required String uid,
    required QrSignData signData,
    required String? cookie,
  }) async {
    final validate = await _solveValidateIfNeeded(
      needVCode: signData.needVCode,
      cookie: cookie,
      referer: signData.captchaReferer,
      accountUid: uid,
    );
    if (validate == null) {
      return const SignFlowResult(success: false, message: '滑块验证码失败');
    }
    final urls = _buildQrSignUrls(
      signData.payloadCandidates,
      uid: uid,
      includeLocation: signData.includeLocation,
      location: signData.locationPayload,
      validate: validate,
    );
    final result = await _trySignUrlsWithCookie(urls, cookie);
    return result ?? const SignFlowResult(success: false, message: '二维码签到失败');
  }

  Future<SignFlowResult> submitLocationSign({
    required String uid,
    required String fid,
    required LocationSignData signData,
    required String? cookie,
  }) async {
    final validate = await _solveValidateIfNeeded(
      needVCode: signData.needVCode,
      cookie: cookie,
      referer: signData.captchaReferer,
      accountUid: uid,
    );
    if (validate == null) {
      return const SignFlowResult(success: false, message: '滑块验证码失败');
    }
    final result = await _submitLocationSignWithCookie(
      aid: signData.aid,
      uid: uid,
      fid: fid,
      latitude: signData.latitude,
      longitude: signData.longitude,
      address: signData.address,
      validate: validate,
      cookie: cookie,
    );
    return result;
  }

  Future<NormalSignData> prepareNormalSign({
    required String courseId,
    required String classId,
    required ActiveTask task,
    required String signCode,
    required String captchaReferer,
    required String? cookie,
    String? preSignUid,
    String? aid,
  }) async {
    final signAid = (aid != null && aid.isNotEmpty) ? aid : task.id;
    final preSignUrl = (preSignUid == null || preSignUid.isEmpty)
        ? task.preSignUrl
        : _setUidInUrl(task.preSignUrl, preSignUid);
    if (signCode.isNotEmpty) {
      await _analysisWithCookie(signAid, cookie);
      await _preSignWithCookie(preSignUrl, cookie);
      await _checkSignCodeSafeWithCookie(signAid, signCode, cookie);
    } else {
      await _preSignWithCookie(preSignUrl, cookie);
    }
    final meta = await _fetchLocationSignMetaWithCookie(
      signAid,
      cookie: cookie,
    );
    return NormalSignData(
      courseId: courseId,
      classId: classId,
      aid: signAid,
      signCode: signCode,
      needVCode: meta.needVCode,
      captchaReferer: captchaReferer,
      preSignUrl: task.preSignUrl,
    );
  }

  Future<SignFlowResult> submitNormalSign({
    required String uid,
    required String? cookie,
    required NormalSignData signData,
  }) async {
    final validate = await _solveValidateIfNeeded(
      needVCode: signData.needVCode,
      cookie: cookie,
      referer: signData.captchaReferer,
      accountUid: uid,
    );
    if (validate == null) {
      return const SignFlowResult(success: false, message: '滑块验证码失败');
    }
    final response = await _dio.get<String>(
      AppUrls.normalSign(
        signData.courseId,
        signData.classId,
        signData.aid,
        signCode: signData.signCode,
        validate: validate,
      ),
      options: Options(headers: _headers(cookie)),
    );
    return _toResult(response.data ?? '');
  }

  Future<PhotoSignData> preparePhotoSign({
    required ActiveTask task,
    required String captchaReferer,
    required String? cookie,
    String? preSignUid,
  }) async {
    final preSignUrl = (preSignUid == null || preSignUid.isEmpty)
        ? task.preSignUrl
        : _setUidInUrl(task.preSignUrl, preSignUid);
    await _preSignWithCookie(preSignUrl, cookie);
    await _analysisWithCookie(task.id, cookie);
    final meta = await _fetchLocationSignMetaWithCookie(
      task.id,
      cookie: cookie,
    );
    return PhotoSignData(
      aid: task.id,
      needVCode: meta.needVCode,
      captchaReferer: captchaReferer,
      preSignUrl: task.preSignUrl,
    );
  }

  Future<SignFlowResult> submitPhotoSign({
    required String uid,
    required String? cookie,
    required String filePath,
    required PhotoSignData signData,
  }) async {
    final validate = await _solveValidateIfNeeded(
      needVCode: signData.needVCode,
      cookie: cookie,
      referer: signData.captchaReferer,
      accountUid: uid,
    );
    if (validate == null) {
      return const SignFlowResult(success: false, message: '滑块验证码失败');
    }
    return _submitPhotoSign(
      aid: signData.aid,
      uid: uid,
      filePath: filePath,
      validate: validate,
      cookie: cookie,
    );
  }

  Future<DirectLocationData> prepareDirectLocationSign({
    required ActiveTask task,
    required String aid,
    required String captchaReferer,
    required String? cookie,
    String? preSignUid,
  }) async {
    await _analysisWithCookie(aid, cookie);
    final preSignUrl = (preSignUid == null || preSignUid.isEmpty)
        ? task.preSignUrl
        : _setUidInUrl(task.preSignUrl, preSignUid);
    final preSignHtml = await _preSignWithCookie(preSignUrl, cookie);
    final meta = await _fetchLocationSignMetaWithCookie(
      aid,
      cookie: cookie,
      preSignHtml: preSignHtml,
    );
    return DirectLocationData(
      aid: aid,
      address: meta.locationText,
      needVCode: meta.needVCode,
      captchaReferer: captchaReferer,
      preSignUrl: task.preSignUrl,
    );
  }

  Future<
    ({
      double? latitude,
      double? longitude,
      bool alreadySigned,
      bool probeSuccess,
    })
  >
  probeDirectLocationSign({
    required String uid,
    required String fid,
    required String? cookie,
    required DirectLocationData signData,
  }) {
    return _resolveLocationByDistance(
      aid: signData.aid,
      uid: uid,
      fid: fid,
      address: signData.address,
      cookie: cookie,
    );
  }

  Future<SignFlowResult> submitDirectLocationSign({
    required String uid,
    required String fid,
    required String? cookie,
    required DirectLocationData signData,
    required double latitude,
    required double longitude,
  }) async {
    final validate = await _solveValidateIfNeeded(
      needVCode: signData.needVCode,
      cookie: cookie,
      referer: signData.captchaReferer,
      accountUid: uid,
    );
    if (validate == null) {
      return const SignFlowResult(success: false, message: '滑块验证码失败');
    }
    return _submitLocationSignWithCookie(
      aid: signData.aid,
      uid: uid,
      fid: fid,
      latitude: latitude,
      longitude: longitude,
      address: signData.address,
      validate: validate,
      cookie: cookie,
    );
  }

  Future<String> preSignTask(String preSignUrl) => _preSign(preSignUrl);

  Future<({bool allowDirectSign, String locationText, bool needVCode})>
  fetchLocationSignMeta(String activeId) {
    return _fetchLocationSignMetaWithCookie(activeId, cookie: null);
  }
}

class _ActiveMetaCacheEntry {
  const _ActiveMetaCacheEntry({
    required this.allowDirectSign,
    required this.locationText,
    required this.needVCode,
    required this.expiresAt,
  });

  final bool allowDirectSign;
  final String locationText;
  final bool needVCode;
  final DateTime expiresAt;
}

class QrSignData {
  const QrSignData({
    required this.analysisAid,
    required this.payloadCandidates,
    required this.includeLocation,
    required this.locationPayload,
    required this.needVCode,
    required this.captchaReferer,
    required this.preSignUrl,
  });

  final String analysisAid;
  final List<String> payloadCandidates;
  final bool includeLocation;
  final String locationPayload;
  final bool needVCode;
  final String captchaReferer;
  final String preSignUrl;
}

class NormalSignData {
  const NormalSignData({
    required this.courseId,
    required this.classId,
    required this.aid,
    required this.signCode,
    required this.needVCode,
    required this.captchaReferer,
    required this.preSignUrl,
  });

  final String courseId;
  final String classId;
  final String aid;
  final String signCode;
  final bool needVCode;
  final String captchaReferer;
  final String preSignUrl;
}

class PhotoSignData {
  const PhotoSignData({
    required this.aid,
    required this.needVCode,
    required this.captchaReferer,
    required this.preSignUrl,
  });

  final String aid;
  final bool needVCode;
  final String captchaReferer;
  final String preSignUrl;
}

class LocationSignData {
  const LocationSignData({
    required this.aid,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.needVCode,
    required this.captchaReferer,
    required this.preSignUrl,
  });

  final String aid;
  final double latitude;
  final double longitude;
  final String address;
  final bool needVCode;
  final String captchaReferer;
  final String preSignUrl;
}

class DirectLocationData {
  const DirectLocationData({
    required this.aid,
    required this.address,
    required this.needVCode,
    required this.captchaReferer,
    required this.preSignUrl,
  });

  final String aid;
  final String address;
  final bool needVCode;
  final String captchaReferer;
  final String preSignUrl;
}

class _DistanceSample {
  const _DistanceSample({
    required this.lat,
    required this.lon,
    required this.meters,
  });

  final double lat;
  final double lon;
  final double meters;
}
