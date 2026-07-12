import 'package:drift/drift.dart' hide Column;
import 'package:supermarket/data/datasources/local/app_database.dart';

class CurrencyConversionService {
  final AppDatabase db;

  CurrencyConversionService(this.db);

  Future<Currency?> getBaseCurrency() async {
    return (db.select(db.currencies)..where((c) => c.isBase.equals(true)))
        .getSingleOrNull();
  }

  Future<Currency?> getCurrencyByCode(String code) async {
    return (db.select(db.currencies)..where((c) => c.code.equals(code)))
        .getSingleOrNull();
  }

  Future<Decimal> convert({
    required Decimal amount,
    required String fromCurrencyCode,
    required String toCurrencyCode,
  }) async {
    if (fromCurrencyCode == toCurrencyCode) return amount;

    final fromCurrency = await getCurrencyByCode(fromCurrencyCode);
    final toCurrency = await getCurrencyByCode(toCurrencyCode);

    if (fromCurrency == null || toCurrency == null) {
      throw Exception('عملة غير موجودة');
    }

    final baseAmount = amount * fromCurrency.exchangeRate;
    final result = baseAmount / toCurrency.exchangeRate;
    return Decimal.parse(result.toString());
  }

  Future<Decimal> convertToBase({
    required Decimal amount,
    required String fromCurrencyCode,
  }) async {
    final fromCurrency = await getCurrencyByCode(fromCurrencyCode);
    if (fromCurrency == null) throw Exception('عملة غير موجودة');
    final result = amount * fromCurrency.exchangeRate;
    return Decimal.parse(result.toString());
  }

  Future<Decimal> convertFromBase({
    required Decimal amount,
    required String toCurrencyCode,
  }) async {
    final toCurrency = await getCurrencyByCode(toCurrencyCode);
    if (toCurrency == null) throw Exception('عملة غير موجودة');
    final result = amount / toCurrency.exchangeRate;
    return Decimal.parse(result.toString());
  }

  Future<List<Currency>> getAllCurrencies() async {
    return (db.select(db.currencies)
          ..orderBy([(c) => OrderingTerm.asc(c.code)]))
        .get();
  }

  Future<Map<String, Decimal>> getAllRates() async {
    final currencies = await getAllCurrencies();
    return {for (final c in currencies) c.code: c.exchangeRate};
  }

  Future<void> updateExchangeRate(String currencyCode, Decimal newRate) async {
    await (db.update(db.currencies)..where((c) => c.code.equals(currencyCode)))
        .write(CurrenciesCompanion(exchangeRate: Value(newRate)));
  }

  Future<Decimal> getExchangeRate(String fromCode, String toCode) async {
    if (fromCode == toCode) return Decimal.one;
    final from = await getCurrencyByCode(fromCode);
    final to = await getCurrencyByCode(toCode);
    if (from == null || to == null) throw Exception('عملة غير موجودة');
    final result = from.exchangeRate / to.exchangeRate;
    return Decimal.parse(result.toString());
  }

  Future<List<Map<String, dynamic>>> getCurrencyDifferences({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final currencies = await getAllCurrencies();

    return currencies
        .map((c) => {
              'code': c.code,
              'name': c.name,
              'rate': c.exchangeRate,
              'isBase': c.isBase,
              'difference':
                  c.isBase ? Decimal.zero : c.exchangeRate - Decimal.one,
            })
        .toList();
  }
}
