import 'package:flutter/material.dart';
import 'package:supermarket/core/services/app_config_service.dart';

class LocaleProvider with ChangeNotifier {
  final AppConfigService _configService;
  Locale _locale = const Locale('ar');

  LocaleProvider(this._configService);

  Locale get locale => _locale;
  String get localeCode => _locale.languageCode;

  Future<void> loadLocale() async {
    final savedLocale = await _configService.getLocaleCode();
    _locale = Locale(_normalizeLocaleCode(savedLocale));
    notifyListeners();
  }

  Future<void> setLocaleCode(String languageCode) async {
    final normalizedCode = _normalizeLocaleCode(languageCode);
    if (_locale.languageCode == normalizedCode) return;

    _locale = Locale(normalizedCode);
    notifyListeners();
    await _configService.setLocaleCode(normalizedCode);
  }

  String _normalizeLocaleCode(String? languageCode) {
    return languageCode == 'en' ? 'en' : 'ar';
  }
}
