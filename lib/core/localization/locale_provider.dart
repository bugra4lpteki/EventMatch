import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _prefKey = 'selected_language_code';
  Locale _locale = const Locale('tr');

  Locale get locale => _locale;
  bool get isTurkish => _locale.languageCode == 'tr';

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey);
      if (code != null && (code == 'tr' || code == 'en')) {
        _locale = Locale(code);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[LocaleProvider] Load error: $e');
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_locale == newLocale) return;
    _locale = newLocale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, newLocale.languageCode);
    } catch (e) {
      debugPrint('[LocaleProvider] Save error: $e');
    }
  }

  void toggleLocale() {
    if (_locale.languageCode == 'tr') {
      setLocale(const Locale('en'));
    } else {
      setLocale(const Locale('tr'));
    }
  }
}
