import 'package:flutter/foundation.dart';

import '../../core/models/active_task.dart';
import '../../core/models/course.dart';
import '../../core/models/linked_account.dart';
import '../../core/models/sign_session.dart';
import '../../core/models/sign_flow_result.dart';
import '../../core/models/sign_type_info.dart';
import '../../core/network/app_dio.dart';
import '../../core/session/sign_session_provider.dart';
import '../../core/storage/app_storage.dart';
import 'course_sign_repository.dart';

class CourseSignController extends ChangeNotifier {
  CourseSignController({
    required AppDio dio,
    required AppStorage storage,
    required this.course,
  }) : _storage = storage,
       _repository = CourseSignRepository(
         dio.client,
         SignSessionProvider(storage: storage, dio: dio.client),
       );

  final Course course;
  final AppStorage _storage;
  final CourseSignRepository _repository;
  final Map<String, ({String html, int ts})> _qrPreSignCache = {};

  bool loading = false;
  bool signing = false;
  String? error;
  List<ActiveTask> tasks = const [];

  String get uid => _storage.loadSession().uid;
  String get fid => _storage.loadSession().fid;
  String get mainUsername => _storage.loadCredentials().username;
  List<LinkedAccount> get linkedAccounts => _storage.loadLinkedAccounts();

  String _buildCaptchaReferer(String activeId) {
    return 'https://mobilelearn.chaoxing.com/page/sign/signIn?courseId=${course.courseId}&classId=${course.classId}&activeId=$activeId&fid=0&timetable=0';
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      tasks = await _repository.loadTasks(
        courseId: course.courseId,
        classId: course.classId,
        uid: uid,
        cpi: course.cpi,
      );
    } catch (_) {
      error = '签到任务加载失败';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<SignTypeInfo> fetchSignType(ActiveTask task) {
    return _repository.fetchSignType(task.id);
  }

  Future<bool> canUseDirectLocationSign(String activeId) async {
    final meta = await _repository.fetchLocationSignMeta(activeId);
    return meta.allowDirectSign;
  }

  Future<SignFlowResult> normalSign(
    ActiveTask task, {
    String signCode = '',
    String? aid,
  }) {
    return _runSign(() async {
      final signAid = (aid != null && aid.isNotEmpty) ? aid : task.id;
      final captchaReferer = _buildCaptchaReferer(signAid);
      final mainSession = _repository.resolveMainSession(uid: uid, fid: fid);
      final mainCookie = _cookieOf(mainSession);
      final signData = await _repository.prepareNormalSign(
        courseId: course.courseId,
        classId: course.classId,
        task: task,
        signCode: signCode,
        captchaReferer: captchaReferer,
        cookie: mainCookie,
        preSignUid: mainSession.uid,
        aid: aid,
      );
      return _runWithLinkedAccounts(
        primary: _repository.submitNormalSign(
          uid: mainSession.uid,
          cookie: mainCookie,
          signData: signData,
        ),
        linkedAction: (account) => _submitLinked(account, (linked) async {
          await _repository.prepareSessionForSign(
            session: linked,
            aid: signData.aid,
            preSignUrl: signData.preSignUrl,
          );
          return _repository.submitNormalSign(
            uid: linked.uid,
            cookie: _cookieOf(linked),
            signData: signData,
          );
        }),
      );
    });
  }

  Future<SignFlowResult> qrCodeSign(ActiveTask task, String qrCodeRaw) {
    final cached = _qrPreSignCache[task.id];
    final now = DateTime.now().millisecondsSinceEpoch;
    final reusePreSignHtml = (cached != null && (now - cached.ts) <= 90 * 1000)
        ? cached.html
        : null;
    return _runSign(() async {
      try {
        final captchaReferer = _buildCaptchaReferer(task.id);
        final mainSession = _repository.resolveMainSession(uid: uid, fid: fid);
        final mainCookie = _cookieOf(mainSession);
        final signData = await _repository.prepareQrSign(
          task: task,
          qrCodeRaw: qrCodeRaw,
          captchaReferer: captchaReferer,
          preSignHtml: reusePreSignHtml,
          cookie: mainCookie,
          preSignUid: mainSession.uid,
        );
        return _runWithLinkedAccounts(
          primary: _repository.submitQrSign(
            uid: mainSession.uid,
            signData: signData,
            cookie: mainCookie,
          ),
          linkedAction: (account) => _submitLinked(account, (linked) async {
            await _repository.prepareSessionForSign(
              session: linked,
              aid: signData.analysisAid,
              preSignUrl: signData.preSignUrl,
            );
            return _repository.submitQrSign(
              uid: linked.uid,
              signData: signData,
              cookie: _cookieOf(linked),
            );
          }),
        );
      } on StateError catch (e) {
        return SignFlowResult(success: false, message: e.message);
      }
    });
  }

  Future<void> preSignForQr(ActiveTask task) async {
    signing = true;
    notifyListeners();
    try {
      final html = await _repository.preSignTask(task.preSignUrl);
      _qrPreSignCache[task.id] = (
        html: html,
        ts: DateTime.now().millisecondsSinceEpoch,
      );
    } finally {
      signing = false;
      notifyListeners();
    }
  }

  Future<SignFlowResult> photoSignBatch(
    ActiveTask task, {
    required String mainFilePath,
    required Map<String, String> linkedFilePaths,
  }) {
    return _runSign(() async {
      final captchaReferer = _buildCaptchaReferer(task.id);
      final mainSession = _repository.resolveMainSession(uid: uid, fid: fid);
      final mainCookie = _cookieOf(mainSession);
      final signData = await _repository.preparePhotoSign(
        task: task,
        captchaReferer: captchaReferer,
        cookie: mainCookie,
        preSignUid: mainSession.uid,
      );
      return _runParallelWithLinkedAccounts(
        primary: _repository.submitPhotoSign(
          uid: mainSession.uid,
          cookie: mainCookie,
          filePath: mainFilePath,
          signData: signData,
        ),
        linkedAction: (account) {
          final filePath = (linkedFilePaths[account.username] ?? '').trim();
          if (filePath.isEmpty) {
            return Future.value(
              const SignFlowResult(success: false, message: '未选择照片'),
            );
          }
          return _submitLinked(account, (linked) async {
            await _repository.prepareSessionForSign(
              session: linked,
              aid: signData.aid,
              preSignUrl: signData.preSignUrl,
            );
            return _repository.submitPhotoSign(
              uid: linked.uid,
              cookie: _cookieOf(linked),
              filePath: filePath,
              signData: signData,
            );
          });
        },
      );
    });
  }

  Future<SignFlowResult> locationSign(
    ActiveTask task, {
    String? aid,
    String fallbackAddress = '',
  }) {
    return _runSign(() async {
      final signAid = (aid != null && aid.isNotEmpty) ? aid : task.id;
      try {
        final captchaReferer = _buildCaptchaReferer(signAid);
        final mainSession = _repository.resolveMainSession(uid: uid, fid: fid);
        final mainCookie = _cookieOf(mainSession);
        final signData = await _repository.prepareCurrentLocationSign(
          task: task,
          aid: signAid,
          fallbackAddress: fallbackAddress,
          captchaReferer: captchaReferer,
          cookie: mainCookie,
          preSignUid: mainSession.uid,
        );
        return _runWithLinkedAccounts(
          primary: _repository.submitLocationSign(
            uid: mainSession.uid,
            fid: mainSession.fid,
            signData: signData,
            cookie: mainCookie,
          ),
          linkedAction: (account) => _submitLinked(account, (linked) async {
            await _repository.prepareSessionForSign(
              session: linked,
              aid: signData.aid,
              preSignUrl: signData.preSignUrl,
            );
            return _repository.submitLocationSign(
              uid: linked.uid,
              fid: linked.fid,
              signData: signData,
              cookie: _cookieOf(linked),
            );
          }),
        );
      } on StateError catch (e) {
        return SignFlowResult(success: false, message: e.message);
      }
    });
  }

  Future<SignFlowResult> locationSignAt(
    ActiveTask task, {
    required double latitude,
    required double longitude,
    String? aid,
    String fallbackAddress = '',
  }) {
    return _runSign(() async {
      final signAid = (aid != null && aid.isNotEmpty) ? aid : task.id;
      try {
        final captchaReferer = _buildCaptchaReferer(signAid);
        final mainSession = _repository.resolveMainSession(uid: uid, fid: fid);
        final mainCookie = _cookieOf(mainSession);
        final signData = await _repository.prepareSelectedLocationSign(
          task: task,
          aid: signAid,
          latitude: latitude,
          longitude: longitude,
          fallbackAddress: fallbackAddress,
          captchaReferer: captchaReferer,
          cookie: mainCookie,
          preSignUid: mainSession.uid,
        );
        return _runWithLinkedAccounts(
          primary: _repository.submitLocationSign(
            uid: mainSession.uid,
            fid: mainSession.fid,
            signData: signData,
            cookie: mainCookie,
          ),
          linkedAction: (account) => _submitLinked(account, (linked) async {
            await _repository.prepareSessionForSign(
              session: linked,
              aid: signData.aid,
              preSignUrl: signData.preSignUrl,
            );
            return _repository.submitLocationSign(
              uid: linked.uid,
              fid: linked.fid,
              signData: signData,
              cookie: _cookieOf(linked),
            );
          }),
        );
      } on StateError catch (e) {
        return SignFlowResult(success: false, message: e.message);
      }
    });
  }

  Future<SignFlowResult> locationDirectSign(ActiveTask task, {String? aid}) {
    return _runSign(() async {
      final signAid = (aid != null && aid.isNotEmpty) ? aid : task.id;
      final mainSession = _repository.resolveMainSession(uid: uid, fid: fid);
      final mainCookie = _cookieOf(mainSession);
      final directContext = await _repository.prepareDirectLocationSign(
        task: task,
        aid: signAid,
        captchaReferer: _buildCaptchaReferer(signAid),
        cookie: mainCookie,
        preSignUid: mainSession.uid,
      );
      final accounts = linkedAccounts;
      final probeSignedLinked = <String>{};
      var primarySignedInProbe = false;

      var probe = await _repository.probeDirectLocationSign(
        uid: mainSession.uid,
        fid: mainSession.fid,
        cookie: mainCookie,
        signData: directContext,
      );
      if (probe.alreadySigned) {
        primarySignedInProbe = true;
      }

      if (!probe.probeSuccess) {
        for (final account in accounts) {
          final linked = await _repository.resolveLinkedSession(
            username: account.username,
            password: account.password,
          );
          if (linked == null) {
            continue;
          }
          await _repository.prepareSessionForSign(
            session: linked,
            aid: directContext.aid,
            preSignUrl: directContext.preSignUrl,
          );
          final linkedProbe = await _repository.probeDirectLocationSign(
            uid: linked.uid,
            fid: linked.fid,
            cookie: _cookieOf(linked),
            signData: directContext,
          );
          if (linkedProbe.alreadySigned) {
            probeSignedLinked.add(account.username);
          }
          if (linkedProbe.probeSuccess ||
              (probe.latitude == null &&
                  probe.longitude == null &&
                  linkedProbe.latitude != null &&
                  linkedProbe.longitude != null)) {
            probe = linkedProbe;
          }
          if (linkedProbe.probeSuccess) {
            break;
          }
        }
      }

      if (probe.latitude == null || probe.longitude == null) {
        final allSigned =
            primarySignedInProbe && probeSignedLinked.length == accounts.length;
        if (allSigned) {
          return const SignFlowResult(success: true, message: '已签到');
        }
        return const SignFlowResult(success: false, message: '直接签到失败');
      }

      final primaryFuture = primarySignedInProbe
          ? Future.value(const SignFlowResult(success: true, message: '已签到'))
          : _repository.submitDirectLocationSign(
              uid: mainSession.uid,
              fid: mainSession.fid,
              cookie: mainCookie,
              signData: directContext,
              latitude: probe.latitude!,
              longitude: probe.longitude!,
            );

      return _runParallelWithLinkedAccounts(
        primary: primaryFuture,
        linkedAction: (account) {
          if (probeSignedLinked.contains(account.username)) {
            return Future.value(
              const SignFlowResult(success: true, message: '已签到'),
            );
          }
          return _submitLinked(account, (linked) async {
            await _repository.prepareSessionForSign(
              session: linked,
              aid: directContext.aid,
              preSignUrl: directContext.preSignUrl,
            );
            return _repository.submitDirectLocationSign(
              uid: linked.uid,
              fid: linked.fid,
              cookie: _cookieOf(linked),
              signData: directContext,
              latitude: probe.latitude!,
              longitude: probe.longitude!,
            );
          });
        },
      );
    });
  }

  String? _cookieOf(SignSession session) {
    return session.cookie.isEmpty ? null : session.cookie;
  }

  Future<SignFlowResult> _submitLinked(
    LinkedAccount account,
    Future<SignFlowResult> Function(SignSession linked) action,
  ) async {
    final linked = await _repository.resolveLinkedSession(
      username: account.username,
      password: account.password,
    );
    if (linked == null) {
      return const SignFlowResult(success: false, message: '关联账号登录失败');
    }
    return action(linked);
  }

  Future<SignFlowResult> _runWithLinkedAccounts({
    required Future<SignFlowResult> primary,
    required Future<SignFlowResult> Function(LinkedAccount account)
    linkedAction,
  }) {
    return _runParallelWithLinkedAccounts(
      primary: primary,
      linkedAction: linkedAction,
    );
  }

  Future<SignFlowResult> _runParallelWithLinkedAccounts({
    required Future<SignFlowResult> primary,
    required Future<SignFlowResult> Function(LinkedAccount account)
    linkedAction,
  }) async {
    final accounts = linkedAccounts;
    final primaryFuture = _safeResult(primary);
    final linkedFutures = [
      for (final account in accounts)
        (account: account, future: _safeResult(linkedAction(account))),
    ];

    final result = await primaryFuture;
    if (accounts.isEmpty) return result;

    final failed = <String>[];
    var anyLinkedSuccess = false;
    for (final item in linkedFutures) {
      final linkedResult = await item.future;
      if (!linkedResult.success) {
        failed.add(_formatLinkedFailed(item.account, linkedResult.message));
      } else {
        anyLinkedSuccess = true;
      }
    }
    if (failed.isNotEmpty) {
      return SignFlowResult(
        success: false,
        message: '主账号签到成功，关联账号失败：${failed.join('、')}',
      );
    }
    if (result.success) return result;
    if (anyLinkedSuccess) {
      return const SignFlowResult(success: true, message: '关联账号签到成功');
    }
    return result;
  }

  Future<SignFlowResult> _safeResult(Future<SignFlowResult> future) async {
    try {
      return await future;
    } catch (_) {
      return const SignFlowResult(success: false, message: '请求异常');
    }
  }

  String _formatLinkedFailed(LinkedAccount account, String message) {
    final msg = message.trim();
    return msg.isEmpty ? account.displayName : '${account.displayName}($msg)';
  }

  Future<SignFlowResult> _runSign(
    Future<SignFlowResult> Function() action,
  ) async {
    signing = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      signing = false;
      notifyListeners();
    }
  }
}
