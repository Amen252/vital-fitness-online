import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static const _storageKey = 'app_locale';
  static const Locale defaultLocale = Locale('en');

  static Locale _locale = defaultLocale;

  static Locale get locale => _locale;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_storageKey);
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
    }
  }

  static Future<void> save(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, locale.languageCode);
  }
}
