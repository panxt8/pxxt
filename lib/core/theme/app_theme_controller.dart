import 'package:flutter/material.dart';

import '../constants/app_keys.dart';
import '../storage/app_storage.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController({required AppStorage storage}) : _storage = storage {
    _themeMode = _loadThemeMode();
  }

  final AppStorage _storage;
  late ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _storage.setString(AppKeys.themeMode, mode.name);
  }

  ThemeMode _loadThemeMode() {
    return switch (_storage.getString(AppKeys.themeMode)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
