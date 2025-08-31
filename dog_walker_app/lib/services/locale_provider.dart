import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 언어 설정(로케일)을 관리하는 Provider.
/// - null은 시스템 기본값을 의미합니다.
class LocaleProvider with ChangeNotifier {
  static const _key = 'app_locale';
  Locale? _locale;

  Locale? get locale => _locale;

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code == null || code.isEmpty) {
      _locale = null; // system default
    } else {
      _locale = Locale(code);
    }
    notifyListeners();
  }

  Future<void> setLocale(String? languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (languageCode == null || languageCode.isEmpty) {
      await prefs.remove(_key);
      _locale = null; // system default
    } else {
      await prefs.setString(_key, languageCode);
      _locale = Locale(languageCode);
    }
    notifyListeners();
  }
}
