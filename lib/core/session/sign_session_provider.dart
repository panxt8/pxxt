import 'dart:convert';

import 'package:dio/dio.dart';

import '../constants/app_keys.dart';
import '../models/sign_session.dart';
import '../network/app_dio.dart';
import '../network/app_urls.dart';
import '../storage/app_storage.dart';

class SignSessionProvider {
  SignSessionProvider({required AppStorage storage, required Dio dio})
    : _storage = storage,
      _dio = dio;

  final AppStorage _storage;
  final Dio _dio;

  final Map<String, _LinkedSessionCacheEntry> _memoryCache = {};
  static const Duration _ttl = Duration(minutes: 20);

  SignSession? getMainSession() {
    final session = _storage.loadSession();
    final username = _storage.loadCredentials().username;
    final signSession = SignSession(
      cookie: session.cookie,
      uid: session.uid,
      fid: session.fid,
      username: username,
    );
    return signSession.isValid ? signSession : null;
  }

  Future<SignSession?> resolveLinkedSession({
    required String username,
    required String password,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh) {
      final cached = _memoryCache[username];
      if (cached != null &&
          cached.password == password &&
          cached.expiresAt.isAfter(now)) {
        return cached.session;
      }

      final persisted = _loadPersistedEntry(username);
      if (persisted != null &&
          persisted.password == password &&
          persisted.expiresAt.isAfter(now)) {
        _memoryCache[username] = persisted;
        return persisted.session;
      }
    }

    final refreshed = await _login(username: username, password: password);
    if (refreshed == null) {
      _memoryCache.remove(username);
      _removePersistedEntry(username);
      return null;
    }

    final entry = _LinkedSessionCacheEntry(
      password: password,
      session: refreshed,
      expiresAt: now.add(_ttl),
    );
    _memoryCache[username] = entry;
    _savePersistedEntry(username, entry);
    return refreshed;
  }

  Future<SignSession?> _login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        AppUrls.login(username, password),
        options: Options(headers: {AppDio.forceCookieHeader: ''}),
      );
      final setCookies =
          (response.headers.map['set-cookie'] ?? const <String>[])
              .cast<String>();
      final cookie = _mergeCookies(setCookies);
      final uidCookie = _extractCookieValue(setCookies, 'UID');
      final uid = uidCookie.isNotEmpty
          ? uidCookie
          : _extractCookieValue(setCookies, '_uid');
      final fidCookie = _extractCookieValue(setCookies, 'fid');
      final fid = fidCookie.isNotEmpty
          ? fidCookie
          : _extractCookieValue(setCookies, 'orgfid');

      final data = _toMap(response.data);
      final status = data['status'];
      final statusFailed =
          status != null &&
          status != true &&
          status.toString().toLowerCase() != 'true' &&
          status.toString() != '1';
      if (statusFailed || cookie.isEmpty || uid.isEmpty) return null;
      return SignSession(
        cookie: cookie,
        uid: uid,
        fid: fid,
        username: username,
      );
    } catch (_) {
      return null;
    }
  }

  _LinkedSessionCacheEntry? _loadPersistedEntry(String username) {
    final raw = _storage.getString(AppKeys.linkedSessions);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final item = map[username];
      if (item is! Map) return null;
      final json = Map<String, dynamic>.from(item);
      final session = SignSession(
        cookie: json['cookie']?.toString() ?? '',
        uid: json['uid']?.toString() ?? '',
        fid: json['fid']?.toString() ?? '',
        username: username,
      );
      if (!session.isValid) return null;
      final expiresAtMs = int.tryParse(json['expiresAtMs']?.toString() ?? '');
      if (expiresAtMs == null) return null;
      final password = json['password']?.toString() ?? '';
      return _LinkedSessionCacheEntry(
        password: password,
        session: session,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMs),
      );
    } catch (_) {
      return null;
    }
  }

  void _savePersistedEntry(String username, _LinkedSessionCacheEntry entry) {
    Map<String, dynamic> all = <String, dynamic>{};
    final raw = _storage.getString(AppKeys.linkedSessions);
    if (raw != null && raw.isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          all = Map<String, dynamic>.from(parsed);
        }
      } catch (_) {}
    }
    all[username] = {
      'password': entry.password,
      'cookie': entry.session.cookie,
      'uid': entry.session.uid,
      'fid': entry.session.fid,
      'expiresAtMs': entry.expiresAt.millisecondsSinceEpoch,
    };
    _storage.setString(AppKeys.linkedSessions, jsonEncode(all));
  }

  void _removePersistedEntry(String username) {
    final raw = _storage.getString(AppKeys.linkedSessions);
    if (raw == null || raw.isEmpty) return;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map) return;
      final all = Map<String, dynamic>.from(parsed);
      all.remove(username);
      _storage.setString(AppKeys.linkedSessions, jsonEncode(all));
    } catch (_) {}
  }

  static Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return jsonDecode(data.toString()) as Map<String, dynamic>;
  }

  static String _mergeCookies(List<String> cookies) {
    final merged = <String>{};
    for (final item in cookies) {
      final first = item.split(';').first.trim();
      if (first.isNotEmpty) merged.add(first);
    }
    return merged.join(';');
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

class _LinkedSessionCacheEntry {
  const _LinkedSessionCacheEntry({
    required this.password,
    required this.session,
    required this.expiresAt,
  });

  final String password;
  final SignSession session;
  final DateTime expiresAt;
}
