import 'package:supermarket/core/constants/app_enums.dart';
import 'package:supermarket/core/services/app_settings_service.dart';

class CurrencyService {
  final AppSettingsService _settingsService;

  CurrencyService(this._settingsService);

  Future<CurrencyType> getDefaultCurrency() async {
    final currency = await _settingsService.getSetting('default_currency');
    if (currency != null) {
      return CurrencyType.values.firstWhere(
        (e) => e.name == currency,
        orElse: () => CurrencyType.sar,
      );
    }
    return CurrencyType.sar;
  }

  Future<void> setDefaultCurrency(CurrencyType currency) async {
    await _settingsService.setSetting('default_currency', currency.name);
  }

  Future<double> getExchangeRate(CurrencyType from, CurrencyType to) async {
    if (from == to) return 1.0;

    final rateKey = 'exchange_rate_${from.name}_${to.name}';
    final rate = await _settingsService.getSetting(rateKey);

    if (rate != null) {
      return double.parse(rate);
    }

    if (from == CurrencyType.sar) {
      final reverseKey = 'exchange_rate_${to.name}_sar';
      final reverseRate = await _settingsService.getSetting(reverseKey);
      if (reverseRate != null) {
        return 1 / double.parse(reverseRate);
      }
    }

    return 1.0;
  }

  Future<void> setExchangeRate(
      CurrencyType from, CurrencyType to, double rate) async {
    final rateKey = 'exchange_rate_${from.name}_${to.name}';
    await _settingsService.setSetting(rateKey, rate.toString());
  }

  Future<Map<CurrencyType, double>> getAllExchangeRates() async {
    final rates = <CurrencyType, double>{};

    for (final currency in CurrencyType.values) {
      if (currency != CurrencyType.sar) {
        rates[currency] = await getExchangeRate(CurrencyType.sar, currency);
      }
    }

    return rates;
  }

  double convert(double amount, CurrencyType from, CurrencyType to, double rate) {
    if (from == to) return amount;
    return amount * rate;
  }

  String formatCurrency(double amount, CurrencyType currency, {int decimals = 2}) {
    return '${currency.symbol}${amount.toStringAsFixed(decimals)}';
  }
}