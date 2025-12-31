import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_strings_id.dart';
import '../localization/app_strings_en.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _appLocale = const Locale('id');

  Locale get appLocale => _appLocale;

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('app_language');
    if (savedLang != null) {
      _appLocale = Locale(savedLang);
      notifyListeners();
    }
  }

  Future<void> changeLanguage(Locale type) async {
    final prefs = await SharedPreferences.getInstance();
    if (_appLocale == type) return;

    if (type == const Locale('id')) {
      _appLocale = const Locale('id');
      await prefs.setString('app_language', 'id');
    } else {
      _appLocale = const Locale('en');
      await prefs.setString('app_language', 'en');
    }
    notifyListeners();
  }
  
  String getText(String key, {List<String>? args}) {
    // Prefer selected language, but fall back to the other language map
    String text;
    if (_appLocale.languageCode == 'id') {
      text = indonesianTexts[key] ?? englishTexts[key] ?? key;
    } else {
      text = englishTexts[key] ?? indonesianTexts[key] ?? key;
    }

    // Simple arg replacement if args provided. Uses @0, @1 etc or @name replacements if present in args.
    if (args != null && args.isNotEmpty) {
      for (int i = 0; i < args.length; i++) {
        text = text.replaceAll('@${i}', args[i]);
      }
    }

    return text;
  }
}
