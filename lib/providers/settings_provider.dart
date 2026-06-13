import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyClaudeApiKey = 'claude_api_key';
  static const _keyTier = 'user_tier';

  String _claudeApiKey = '';
  String _tier = 'free';

  String get claudeApiKey => _claudeApiKey;
  String get tier => _tier;
  bool get hasClaudeKey => _claudeApiKey.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _claudeApiKey = prefs.getString(_keyClaudeApiKey) ?? '';
    _tier = prefs.getString(_keyTier) ?? 'free';
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
}
