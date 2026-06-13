import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyClaudeApiKey = 'claude_api_key';
  static const _keyTier = 'user_tier';
  static const _keyThemeMode = 'theme_mode';

  String _claudeApiKey = '';
  String _tier = 'free';
  ThemeMode _themeMode = ThemeMode.system;

  String get claudeApiKey => _claudeApiKey;
  String get tier => _tier;
  bool get hasClaudeKey => _claudeApiKey.isNotEmpty;
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _claudeApiKey = prefs.getString(_keyClaudeApiKey) ?? '';
    _tier = prefs.getString(_keyTier) ?? 'free';
    final tm = prefs.getString(_keyThemeMode) ?? 'system';
    _themeMode = _parseThemeMode(tm);
    notifyListeners();
  }

  Future<void> setClaudeApiKey(String key) async {
    _claudeApiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyClaudeApiKey, key);
    notifyListeners();
  }

  Future<void> setTier(String tier) async {
    _tier = tier;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTier, tier);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, _serializeThemeMode(mode));
    notifyListeners();
  }

  static ThemeMode _parseThemeMode(String s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _serializeThemeMode(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      };
}
