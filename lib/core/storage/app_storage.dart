import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_keys.dart';
import '../models/app_session.dart';
import '../models/linked_account.dart';

class AppStorage {
  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  AppSession loadSession() {
    return AppSession(
      cookie: _prefs.getString(AppKeys.cookie) ?? '',
      uid: _prefs.getString(AppKeys.uid) ?? '',
      fid: _prefs.getString(AppKeys.fid) ?? '',
    );
  }

  Future<void> saveSession(AppSession session) async {
    await _prefs.setString(AppKeys.cookie, session.cookie);
    await _prefs.setString(AppKeys.uid, session.uid);
    await _prefs.setString(AppKeys.fid, session.fid);
  }

  Future<void> clearSession() async {
    await _prefs.remove(AppKeys.cookie);
    await _prefs.remove(AppKeys.uid);
    await _prefs.remove(AppKeys.fid);
  }

  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    await _prefs.setString(AppKeys.username, username);
    await _prefs.setString(AppKeys.password, password);
  }

  ({String username, String password}) loadCredentials() {
    return (
      username: _prefs.getString(AppKeys.username) ?? '',
      password: _prefs.getString(AppKeys.password) ?? '',
    );
  }

  Future<void> clearCredentials() async {
    await _prefs.remove(AppKeys.username);
    await _prefs.remove(AppKeys.password);
  }

  List<LinkedAccount> loadLinkedAccounts() {
    final raw = _prefs.getString(AppKeys.linkedAccounts);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((e) => LinkedAccount.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.username.isNotEmpty && e.password.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveLinkedAccounts(List<LinkedAccount> accounts) async {
    final data = accounts.map((e) => e.toJson()).toList();
    await _prefs.setString(AppKeys.linkedAccounts, jsonEncode(data));
  }

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
