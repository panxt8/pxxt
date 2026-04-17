import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_keys.dart';
import '../storage/app_storage.dart';

class AppDio {
  AppDio._(this.client);

  static const forceCookieHeader = 'x-force-cookie';

  final Dio client;

  static Future<AppDio> create(AppStorage storage) async {
    final dir = await getApplicationDocumentsDirectory();
    final cookieJar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage('${dir.path}/cookies'),
    );
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: {
          'Accept-Language': 'zh-Hans-CN;q=1, zh-Hant-CN;q=0.9',
          'Accept-Encoding': 'identity',
        },
      ),
    );
    dio.interceptors.add(CookieManager(cookieJar));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final hasForcedCookie = options.headers.containsKey(
            forceCookieHeader,
          );
          final forcedCookie =
              options.headers.remove(forceCookieHeader)?.toString() ?? '';
          if (hasForcedCookie) {
            if (forcedCookie.isEmpty) {
              options.headers.remove(HttpHeaders.cookieHeader);
            } else {
              options.headers[HttpHeaders.cookieHeader] = forcedCookie;
            }
            handler.next(options);
            return;
          }
          final cookie = storage.getString(AppKeys.cookie);
          if (cookie != null && cookie.isNotEmpty) {
            options.headers[HttpHeaders.cookieHeader] = cookie;
          }
          handler.next(options);
        },
      ),
    );
    return AppDio._(dio);
  }
}
