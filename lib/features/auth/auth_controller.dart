import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/models/app_session.dart';
import '../../core/network/app_dio.dart';
import '../../core/storage/app_storage.dart';
import 'auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController({required AppStorage storage, required AppDio dio})
    : _storage = storage,
      _repository = AuthRepository(dio.client);

  final AppStorage _storage;
  final AuthRepository _repository;

  bool ready = false;
  bool loading = false;
  String? error;
  AppSession? session;

  bool get isLoggedIn => session?.isValid == true;

  void restoreSession() {
    session = _storage.loadSession();
    ready = true;
    notifyListeners();
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _repository.login(
        username: username,
        password: password,
      );
      final headers = result.headers.map;
      final setCookies = headers['set-cookie'] ?? const [];
      final cookie = _mergeCookies(setCookies.cast<String>());
      final uidFromCookie = _extractCookieValue(setCookies, 'UID');
      final uid = uidFromCookie.isNotEmpty
          ? uidFromCookie
          : _extractCookieValue(setCookies, '_uid');
      final fidFromCookie = _extractCookieValue(setCookies, 'fid');
      final fid = fidFromCookie.isNotEmpty
          ? fidFromCookie
          : _extractCookieValue(setCookies, 'orgfid');
      final body = result.data is Map<String, dynamic>
          ? result.data as Map<String, dynamic>
          : jsonDecode(result.data.toString()) as Map<String, dynamic>;
      if (body['status'] != true || cookie.isEmpty || uid.isEmpty) {
        error = '登录失败';
        return false;
      }
      session = AppSession(cookie: cookie, uid: uid, fid: fid);
      await _storage.saveSession(session!);
      await _storage.saveCredentials(username: username, password: password);
      return true;
    } catch (_) {
      error = '登录失败';
      return false;
    } finally {
      loading = false;
      ready = true;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    session = const AppSession(cookie: '', uid: '', fid: '');
    await _storage.clearSession();
    notifyListeners();
  }

  static String _mergeCookies(List<String> cookies) {
    return cookies
        .map((item) => item.split(';').first)
        .where((item) => item.isNotEmpty)
        .join(';');
  }

  static String _extractCookieValue(List<String> cookies, String key) {
    for (final item in cookies) {
      final first = item.split(';').first;
      if (first.startsWith('$key=')) {
        return first.substring(key.length + 1);
      }
    }
    return '';
  }
}
