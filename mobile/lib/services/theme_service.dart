import 'package:shared_preferences/shared_preferences.dart';

/// Persists the app-wide light/dark preference (device-local only).
class ThemeService {
  static const _storageKey = 'app_theme_dark';

  static bool _isDark = false;

  static bool get isDark => _isDark;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_storageKey) ?? false;
  }

  static Future<void> save(bool isDark) async {
    _isDark = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storageKey, isDark);
  }
}
