import 'package:drift/drift.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class CurrencyConverterService {
  final AppDatabase db;

  CurrencyConverterService(this.db);

  static const String defaultCurrency = 'SAR';
  static const Map<CurrencyType, double> defaultRates = {
    CurrencyType.sar: 1.0,
    CurrencyType.usd: 3.75,
    CurrencyType.eur: 4.05,
    CurrencyType.gbp: 4.75,
    CurrencyType.aed: 1.02,
  };

  Future<String> getDefaultCurrency() async {
    final setting = await (db.select(db.appConfigTable)
      ..where((t) => t.key.equals('default_currency'))).getSingleOrNull();
    return setting?.value ?? defaultCurrency;
  }

  Future<void> setDefaultCurrency(String currencyCode) async {
    await db.into(db.appConfigTable).insertOnConflictUpdate(
      AppConfigTableCompanion.insert(
        key: currencyCode,
        value: Value(currencyCode),
      ),
    );
  }

  Future<double> getExchangeRate(String fromCurrency, String toCurrency) async {
    if (fromCurrency == toCurrency) return 1.0;

    final setting = await (db.select(db.appConfigTable)
      ..where((t) => t.key.equals('exchange_rate_${fromCurrency}_$toCurrency'))).getSingleOrNull();
    
    if (setting != null && setting.value != null) {
      return double.tryParse(setting.value!) ?? 1.0;
    }

    final fromType = CurrencyType.values.firstWhere(
      (e) => e.name.toUpperCase() == fromCurrency.toUpperCase(),
      orElse: () => CurrencyType.sar,
    );
    return defaultRates[fromType] ?? 1.0;
  }

  Future<void> setExchangeRate(String fromCurrency, String toCurrency, double rate) async {
    await db.into(db.appConfigTable).insertOnConflictUpdate(
      AppConfigTableCompanion.insert(
        key: 'exchange_rate_${fromCurrency}_$toCurrency',
        value: Value(rate.toString()),
      ),
    );
  }

  Future<double> convert(double amount, String fromCurrency, String toCurrency) async {
    final rate = await getExchangeRate(fromCurrency, toCurrency);
    return amount * rate;
  }

  String formatCurrency(double amount, String currencyCode) {
    final currency = CurrencyType.values.firstWhere(
      (e) => e.name.toUpperCase() == currencyCode.toUpperCase(),
      orElse: () => CurrencyType.sar,
    );
    return '${currency.symbol} ${amount.toStringAsFixed(2)}';
  }

  static List<CurrencyType> get availableCurrencies => CurrencyType.values;
}