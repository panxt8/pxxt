part of 'course_sign_repository.dart';

mixin _CourseSignRepositoryHelpers {
  Dio get _dio;

  Map<String, _ActiveMetaCacheEntry> get _activeMetaCache;

  Future<SignFlowResult> _submitPhotoSign({
    required String aid,
    required String uid,
    required String filePath,
    String validate = '',
    required String? cookie,
  }) async {
    final tokenResponse = await _dio.get<dynamic>(
      AppUrls.uploadToken(),
      options: Options(headers: _headers(cookie)),
    );
    final tokenData = _asMap(tokenResponse.data);
    final token = tokenData['_token']?.toString() ?? '';
    if (token.isEmpty) {
      return const SignFlowResult(success: false, message: '上传令牌获取失败');
    }

    final file = await MultipartFile.fromFile(filePath);
    final uploadResponse = await _dio.post<dynamic>(
      AppUrls.uploadImage(token),
      data: FormData.fromMap({'file': file, 'puid': uid}),
      options: Options(headers: _headers(cookie)),
    );
    final uploadData = _asMap(uploadResponse.data);
    final objectId = uploadData['objectId']?.toString() ?? '';
    if (objectId.isEmpty) {
      return const SignFlowResult(success: false, message: '图片上传失败');
    }

    final signResponse = await _dio.get<String>(
      AppUrls.photoSign(aid, uid, objectId, validate: validate),
      options: Options(headers: _headers(cookie)),
    );
    return _toResult(signResponse.data ?? '');
  }

  Future<String> _solveSlideCaptcha({
    required String? cookie,
    required String referer,
    String accountUid = 'main',
  }) async {
    const maxAttempts = 5;
    for (var attempt = 1; attempt <= maxAttempts; attempt += 1) {
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        final nonce = _randomHex(32);
        final captchaKey = _md5Hex('$now$nonce');
        final tokenMd5 = _md5Hex(
          '$now${CourseSignRepository._captchaId}slide$captchaKey',
        );
        final fullToken = '$tokenMd5:${now + 300000}';
        final iv = _md5Hex('${CourseSignRepository._captchaId}slide$now$nonce');

        final imageResponse = await _dio.get<String>(
          'https://captcha.chaoxing.com/captcha/get/verification/image',
          queryParameters: {
            'callback': 'cx_captcha_function',
            'captchaId': CourseSignRepository._captchaId,
            'type': 'slide',
            'version': '1.1.20',
            'captchaKey': captchaKey,
            'token': fullToken,
            'referer': referer,
            'iv': iv,
            '_': now,
          },
          options: Options(headers: {..._headers(cookie), 'Referer': referer}),
        );
        final imageData = _decodeCaptchaJsonp(imageResponse.data ?? '');
        final token = imageData['token']?.toString() ?? '';
        final imageVo = imageData['imageVerificationVo'];
        if (token.isEmpty || imageVo is! Map) {
          continue;
        }
        final shadeUrl = imageVo['shadeImage']?.toString() ?? '';
        final cutoutUrl = imageVo['cutoutImage']?.toString() ?? '';
        if (shadeUrl.isEmpty || cutoutUrl.isEmpty) {
          continue;
        }

        final bgResp = await _dio.get<List<int>>(
          shadeUrl,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {..._headers(cookie), 'Referer': referer},
          ),
        );
        final sliderResp = await _dio.get<List<int>>(
          cutoutUrl,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {..._headers(cookie), 'Referer': referer},
          ),
        );
        final bgBytes = bgResp.data;
        final sliderBytes = sliderResp.data;
        if (bgBytes == null || sliderBytes == null) {
          continue;
        }
        final distance = calculateDistance(
          Uint8List.fromList(bgBytes),
          Uint8List.fromList(sliderBytes),
        );

        final resultResponse = await _dio.get<String>(
          'https://captcha.chaoxing.com/captcha/check/verification/result',
          queryParameters: {
            'callback': 'cx_captcha_function',
            'captchaId': CourseSignRepository._captchaId,
            'type': 'slide',
            'token': token,
            'textClickArr': jsonEncode([
              {'x': distance},
            ]),
            'coordinate': '[]',
            'runEnv': '10',
            'version': '1.1.20',
            't': 'a',
            'iv': iv,
            '_': DateTime.now().millisecondsSinceEpoch,
          },
          options: Options(headers: {..._headers(cookie), 'Referer': referer}),
        );
        final resultData = _decodeCaptchaJsonp(resultResponse.data ?? '');
        final ok =
            resultData['error']?.toString() == '0' &&
            resultData['result']?.toString() == 'true';
        if (!ok) {
          continue;
        }
        final extra = resultData['extraData']?.toString() ?? '';
        if (extra.isEmpty) {
          continue;
        }
        final extraData = _asMap(extra);
        final validate = extraData['validate']?.toString() ?? '';
        if (validate.isNotEmpty) return validate;
      } catch (_) {
        continue;
      }
    }
    return '';
  }

  Future<void> _analysisWithCookie(String aid, String? cookie) async {
    final response = await _dio
        .get<String>(
          AppUrls.analysis(aid),
          options: Options(headers: _headers(cookie)),
        )
        .timeout(const Duration(seconds: 10));
    final body = response.data ?? '';
    final code = body.split("code='+'").length > 1
        ? body.split("code='+'").last.split("'").first
        : '';
    if (code.isNotEmpty) {
      await _dio
          .get<dynamic>(
            AppUrls.analysis2(code),
            options: Options(headers: _headers(cookie)),
          )
          .timeout(const Duration(seconds: 10));
    }
  }

  Future<String> _preSign(String url) async {
    return _preSignWithCookie(url, null);
  }

  Future<String> _preSignWithCookie(String url, String? cookie) async {
    if (url.isEmpty) return '';
    final response = await _dio
        .get<String>(url, options: Options(headers: _headers(cookie)))
        .timeout(const Duration(seconds: 10));
    return response.data ?? '';
  }

  Future<void> _checkSignCodeSafeWithCookie(
    String aid,
    String signCode,
    String? cookie,
  ) async {
    try {
      await _dio.get<dynamic>(
        AppUrls.checkSignCode(aid, signCode),
        options: Options(headers: _headers(cookie)),
      );
    } catch (_) {}
  }

  Future<String> _buildLocationPayload({required String address}) async {
    final position = await _getCurrentPosition();

    final submitLat = position.latitude;
    final submitLon = position.longitude;
    final location = jsonEncode({
      'result': 1,
      'latitude': submitLat,
      'longitude': submitLon,
      'address': address,
    });
    final encoded = Uri.encodeComponent(location);
    return encoded;
  }

  Future<BaiduLocationPoint> _getCurrentPosition() async {
    try {
      final point = await BaiduLocationService.instance.locateOnce();
      return point;
    } on StateError {
      rethrow;
    } catch (_) {
      throw StateError('百度定位失败，请重试');
    }
  }

  Future<SignFlowResult> _submitLocationSignWithCookie({
    required String aid,
    required String uid,
    required String fid,
    required double latitude,
    required double longitude,
    required String address,
    String validate = '',
    required String? cookie,
  }) async {
    final body = await _requestLocationSignBody(
      aid: aid,
      uid: uid,
      fid: fid,
      latitude: latitude,
      longitude: longitude,
      address: address,
      validate: validate,
      cookie: cookie,
    );
    return _toResult(body);
  }

  Future<String> _requestLocationSignBody({
    required String aid,
    required String uid,
    required String fid,
    required double latitude,
    required double longitude,
    required String address,
    String validate = '',
    required String? cookie,
  }) async {
    final url = AppUrls.locationSign(
      address: Uri.encodeComponent(address),
      aid: aid,
      uid: uid,
      latitude: latitude.toString(),
      longitude: longitude.toString(),
      fid: fid,
      validate: validate,
    );
    final response = await _dio
        .get<String>(url, options: Options(headers: _headers(cookie)))
        .timeout(const Duration(seconds: 12));
    final body = response.data ?? '';
    return body;
  }

  Future<
    ({
      double? latitude,
      double? longitude,
      bool alreadySigned,
      bool probeSuccess,
    })
  >
  _resolveLocationByDistance({
    required String aid,
    required String uid,
    required String fid,
    required String address,
    required String? cookie,
  }) async {
    const macro = <({double lat, double lon})>[
      (lat: 39.9042, lon: 116.4074),
      (lat: 31.2304, lon: 121.4737),
      (lat: 23.1291, lon: 113.2644),
    ];

    final coarse = await _solveCoordinates(
      samplesFrom: macro,
      aid: aid,
      uid: uid,
      fid: fid,
      address: address,
      cookie: cookie,
    );
    if (coarse.probeSuccess) return coarse;
    if (coarse.latitude == null || coarse.longitude == null) {
      return coarse;
    }

    const d = 0.04;
    final micro = <({double lat, double lon})>[
      (lat: coarse.latitude! + d, lon: coarse.longitude!),
      (lat: coarse.latitude! - d / 2, lon: coarse.longitude! + d),
      (lat: coarse.latitude! - d / 2, lon: coarse.longitude! - d),
    ];

    final fine = await _solveCoordinates(
      samplesFrom: micro,
      aid: aid,
      uid: uid,
      fid: fid,
      address: address,
      cookie: cookie,
    );
    if (fine.probeSuccess) return fine;
    if (fine.latitude == null || fine.longitude == null) {
      return (
        latitude: coarse.latitude,
        longitude: coarse.longitude,
        alreadySigned: fine.alreadySigned || coarse.alreadySigned,
        probeSuccess: false,
      );
    }
    return fine;
  }

  Future<
    ({
      double? latitude,
      double? longitude,
      bool alreadySigned,
      bool probeSuccess,
    })
  >
  _solveCoordinates({
    required List<({double lat, double lon})> samplesFrom,
    required String aid,
    required String uid,
    required String fid,
    required String address,
    required String? cookie,
  }) async {
    final samples = <_DistanceSample>[];
    var alreadySigned = false;
    for (final p in samplesFrom) {
      final body = await _requestLocationSignBody(
        aid: aid,
        uid: uid,
        fid: fid,
        latitude: p.lat,
        longitude: p.lon,
        address: address,
        cookie: cookie,
      );
      final dist = _extractDistanceMeters(body);
      if (dist != null) {
        samples.add(_DistanceSample(lat: p.lat, lon: p.lon, meters: dist));
      }
      if (_isSuccessOnlyBody(body)) {
        return (
          latitude: p.lat,
          longitude: p.lon,
          alreadySigned: false,
          probeSuccess: true,
        );
      }
      if (_isAlreadySignedBody(body)) {
        alreadySigned = true;
      }
    }
    if (samples.length < 3) {
      return (
        latitude: null,
        longitude: null,
        alreadySigned: alreadySigned,
        probeSuccess: false,
      );
    }
    final solved = _nelderMeadSolve(samples);
    return (
      latitude: solved?.latitude,
      longitude: solved?.longitude,
      alreadySigned: alreadySigned,
      probeSuccess: false,
    );
  }

  double? _extractDistanceMeters(String body) {
    final m = CourseSignRepository._distanceRegExp.firstMatch(body);
    if (m == null) return null;
    return double.tryParse(m.group(1) ?? '');
  }

  ({double latitude, double longitude})? _nelderMeadSolve(
    List<_DistanceSample> samples,
  ) {
    if (samples.length < 3) return null;
    final simplex = <List<double>>[
      [samples[0].lat, samples[0].lon],
      [samples[1].lat, samples[1].lon],
      [samples[2].lat, samples[2].lon],
    ];
    final values = <double>[
      _loss(simplex[0], samples),
      _loss(simplex[1], samples),
      _loss(simplex[2], samples),
    ];

    const alpha = 1.0;
    const gamma = 2.0;
    const rho = 0.5;
    const sigma = 0.5;

    for (var iter = 0; iter < 120; iter++) {
      final order = [0, 1, 2]..sort((a, b) => values[a].compareTo(values[b]));
      final best = order[0];
      final good = order[1];
      final worst = order[2];

      final cx = (simplex[best][0] + simplex[good][0]) / 2;
      final cy = (simplex[best][1] + simplex[good][1]) / 2;

      final rx = cx + alpha * (cx - simplex[worst][0]);
      final ry = cy + alpha * (cy - simplex[worst][1]);
      final reflected = _clipLatLon(rx, ry);
      final fr = _loss([reflected.latitude, reflected.longitude], samples);

      if (fr < values[best]) {
        final ex = cx + gamma * (reflected.latitude - cx);
        final ey = cy + gamma * (reflected.longitude - cy);
        final expanded = _clipLatLon(ex, ey);
        final fe = _loss([expanded.latitude, expanded.longitude], samples);
        if (fe < fr) {
          simplex[worst] = [expanded.latitude, expanded.longitude];
          values[worst] = fe;
        } else {
          simplex[worst] = [reflected.latitude, reflected.longitude];
          values[worst] = fr;
        }
      } else if (fr < values[good]) {
        simplex[worst] = [reflected.latitude, reflected.longitude];
        values[worst] = fr;
      } else {
        final cx2 = cx + rho * (simplex[worst][0] - cx);
        final cy2 = cy + rho * (simplex[worst][1] - cy);
        final contracted = _clipLatLon(cx2, cy2);
        final fc = _loss([contracted.latitude, contracted.longitude], samples);
        if (fc < values[worst]) {
          simplex[worst] = [contracted.latitude, contracted.longitude];
          values[worst] = fc;
        } else {
          simplex[good] = [
            simplex[best][0] + sigma * (simplex[good][0] - simplex[best][0]),
            simplex[best][1] + sigma * (simplex[good][1] - simplex[best][1]),
          ];
          simplex[worst] = [
            simplex[best][0] + sigma * (simplex[worst][0] - simplex[best][0]),
            simplex[best][1] + sigma * (simplex[worst][1] - simplex[best][1]),
          ];
          values[good] = _loss(simplex[good], samples);
          values[worst] = _loss(simplex[worst], samples);
        }
      }

      final maxDiff = values
          .map((v) => (v - values[best]).abs())
          .reduce((a, b) => a > b ? a : b);
      if (maxDiff < 1e-2) break;
    }

    final bestIndex = [0, 1, 2]..sort((a, b) => values[a].compareTo(values[b]));
    final best = simplex[bestIndex.first];
    return (latitude: best[0], longitude: best[1]);
  }

  ({double latitude, double longitude}) _clipLatLon(
    double latitude,
    double longitude,
  ) {
    final lat = latitude.clamp(-85.0, 85.0);
    final lon = longitude.clamp(-180.0, 180.0);
    return (latitude: lat, longitude: lon);
  }

  double _loss(List<double> guess, List<_DistanceSample> samples) {
    final lat = guess[0];
    final lon = guess[1];
    var loss = 0.0;
    for (final s in samples) {
      final d = _haversineMeters(lat, lon, s.lat, s.lon);
      final err = d - s.meters;
      loss += err * err;
    }
    return loss;
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6378137.0;
    final p1 = lat1 * math.pi / 180.0;
    final p2 = lat2 * math.pi / 180.0;
    final dp = (lat2 - lat1) * math.pi / 180.0;
    final dl = (lon2 - lon1) * math.pi / 180.0;
    final a =
        math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  String _matchValue(String html, String key) {
    final quoted = RegExp('"$key"\\s*:\\s*"?([^",}]+)').firstMatch(html);
    if (quoted != null) return quoted.group(1) ?? '';
    final input = RegExp('id="$key"[^>]*value="([^"]*)"').firstMatch(html);
    return input?.group(1) ?? '';
  }

  String _extractInputValue(String html, String id) {
    final m = RegExp('id="$id"[^>]*value="([^"]*)"').firstMatch(html);
    return m?.group(1) ?? '';
  }

  Map<String, dynamic> _decodeCaptchaJsonp(String text) {
    final match = RegExp(
      r'cx_captcha_function\((.*)\)$',
    ).firstMatch(text.trim());
    if (match == null) return <String, dynamic>{};
    final jsonText = match.group(1) ?? '';
    if (jsonText.isEmpty) return <String, dynamic>{};
    return _asMap(jsonText);
  }

  String _randomHex(int length) {
    const chars = '0123456789abcdef';
    final rand = math.Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < length; i++) {
      buf.write(chars[rand.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  String _md5Hex(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  String _extractQrCodePayload(String raw) {
    final text = raw.trim();
    final idIndex = text.indexOf('id=');
    if (idIndex >= 0) {
      return text.substring(idIndex + 3).trim();
    }
    return text;
  }

  String _extractAnalysisAid(String qrCodePayload) {
    final firstPart = qrCodePayload.split('&').first.trim();
    if (firstPart.isEmpty) return '';
    if (CourseSignRepository._allDigitsRegExp.hasMatch(firstPart)) {
      return firstPart;
    }

    var normalized = firstPart;
    if (normalized.startsWith('SIGNIN:')) {
      normalized = normalized.substring('SIGNIN:'.length);
    }
    if (normalized.startsWith('aid=')) {
      final aid = normalized.substring(4).trim();
      if (aid.isNotEmpty) return aid;
    }

    final aidMatch = CourseSignRepository._aidInPayloadRegExp.firstMatch(
      qrCodePayload,
    );
    if (aidMatch != null) {
      return (aidMatch.group(1) ?? '').trim();
    }
    return '';
  }

  List<String> _buildQrPayloadCandidates(String payload) {
    final set = <String>{};

    void add(String value) {
      final v = value.trim();
      if (v.isNotEmpty) set.add(v);
    }

    add(payload);

    var normalized = payload.trim();
    if (normalized.startsWith('SIGNIN:')) {
      normalized = normalized.substring('SIGNIN:'.length).trim();
      add(normalized);
    }

    if (normalized.startsWith('aid=')) {
      add(normalized.substring(4).trim());
    }

    final aidInPayload = CourseSignRepository._aidInPayloadRegExp.firstMatch(
      payload,
    );
    if (aidInPayload != null) {
      final aid = (aidInPayload.group(1) ?? '').trim();
      if (aid.isNotEmpty) {
        final afterAid = payload.split('&').skip(1).join('&');
        add(afterAid.isEmpty ? aid : '$aid&$afterAid');
      }
    }

    return set.toList();
  }

  List<String> _buildQrSignUrls(
    List<String> payloadCandidates, {
    required String uid,
    required bool includeLocation,
    required String location,
    String validate = '',
  }) {
    final urls = <String>{};
    for (final payload in payloadCandidates) {
      if (includeLocation) {
        final base = AppUrls.signWithCamera(
          payload,
          location,
          validate: validate,
        );
        urls.add(base);
        urls.add('$base&uid=$uid');
      } else {
        final base = AppUrls.signWithCameraNoLocation(
          payload,
          validate: validate,
        );
        urls.add(base);
        urls.add('$base&uid=$uid');
      }
    }
    final built = urls.toList();
    return built;
  }

  Future<SignFlowResult?> _trySignUrlsWithCookie(
    List<String> urls,
    String? cookie, {
    SignFlowResult? lastResult,
  }) async {
    for (final url in urls) {
      for (var attempt = 1; attempt <= 2; attempt++) {
        try {
          final response = await _dio
              .get<String>(url, options: Options(headers: _headers(cookie)))
              .timeout(const Duration(seconds: 12));
          final result = _toResult(response.data ?? '');
          lastResult = result;
          if (result.success) {
            return result;
          }
          break;
        } catch (_) {
          if (attempt == 2) break;
        }
      }
    }
    return lastResult;
  }

  SignFlowResult _toResult(String body) {
    final success = _isSuccessfulBody(body);
    return SignFlowResult(
      success: success,
      message: body.isEmpty ? (success ? '签到成功' : '签到失败') : body,
    );
  }

  bool _isSuccessfulBody(String body) {
    if (body.isEmpty) return false;
    return body.contains('success') ||
        body.contains('成功') ||
        body.contains('已签到') ||
        body.contains('已签过') ||
        body.contains('请勿重复签到');
  }

  bool _isAlreadySignedBody(String body) {
    if (body.isEmpty) return false;
    return body.contains('已签到') ||
        body.contains('已签过') ||
        body.contains('重复签到') ||
        body.contains('请勿重复签到');
  }

  bool _isSuccessOnlyBody(String body) {
    if (body.isEmpty) return false;
    return body.contains('success') || body.contains('成功');
  }

  Map<String, String> _headers(String? cookie) {
    final headers = Map<String, String>.from(CourseSignRepository._signHeaders);
    if (cookie != null) {
      headers[CourseSignRepository._forceCookieHeader] = cookie;
    }
    return headers;
  }

  String _setUidInUrl(String url, String uid) {
    if (url.isEmpty || uid.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final query = Map<String, String>.from(uri.queryParameters);
    query['uid'] = uid;
    return uri.replace(queryParameters: query).toString();
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return jsonDecode(data.toString()) as Map<String, dynamic>;
  }

  String _resolveAddress({
    required String locationText,
    required String fallbackAddress,
  }) {
    final primary = locationText.trim();
    if (primary.isNotEmpty) return primary;
    return fallbackAddress.trim();
  }

  Future<({bool allowDirectSign, String locationText, bool needVCode})>
  _fetchLocationSignMetaWithCookie(
    String activeId, {
    required String? cookie,
    String? preSignHtml,
  }) async {
    final htmlLocationText = _extractInputValue(
      preSignHtml ?? '',
      'locationText',
    ).trim();
    var locationText = htmlLocationText;
    var allowDirectSign = false;
    var needVCode = false;
    final now = DateTime.now();

    final cached = _activeMetaCache[activeId];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return (
        allowDirectSign: cached.allowDirectSign,
        locationText: cached.locationText.isNotEmpty
            ? cached.locationText
            : htmlLocationText,
        needVCode: cached.needVCode,
      );
    }

    try {
      final response = await _dio.get<dynamic>(
        AppUrls.pptActiveInfo(activeId),
        options: Options(headers: _headers(cookie)),
      );
      final data = _asMap(response.data)['data'];
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final rawText = map['locationText']?.toString().trim() ?? '';
        if (rawText.isNotEmpty) {
          locationText = rawText;
        }
        final ifopenAddress = int.tryParse(
          map['ifopenAddress']?.toString() ?? '',
        );
        if (ifopenAddress != null) {
          allowDirectSign = ifopenAddress == 1;
        }
        final ifNeedVCode = int.tryParse(map['ifNeedVCode']?.toString() ?? '');
        if (ifNeedVCode != null) {
          needVCode = ifNeedVCode == 1;
        }
      }
      _activeMetaCache[activeId] = _ActiveMetaCacheEntry(
        allowDirectSign: allowDirectSign,
        locationText: locationText,
        needVCode: needVCode,
        expiresAt: now.add(CourseSignRepository._activeMetaTtl),
      );
    } catch (_) {
      if (cached != null) {
        return (
          allowDirectSign: cached.allowDirectSign,
          locationText: cached.locationText.isNotEmpty
              ? cached.locationText
              : htmlLocationText,
          needVCode: cached.needVCode,
        );
      }
    }
    return (
      allowDirectSign: allowDirectSign,
      locationText: locationText,
      needVCode: needVCode,
    );
  }
}
