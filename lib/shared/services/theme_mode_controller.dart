import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeController extends ChangeNotifier {
  static const _key = 'theme_mode'; // 'light' | 'dark' | 'system'

  ThemeMode _mode;
  ThemeModeController._(this._mode);

  static Future<ThemeModeController> load() async {
    final sp = await SharedPreferences.getInstance();
    final mode = switch (sp.getString(_key)) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    return ThemeModeController._(mode);
  }

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        _key,
        switch (mode) {
          ThemeMode.dark => 'dark',
          ThemeMode.light => 'light',
          ThemeMode.system => 'system',
        });
  }
}
