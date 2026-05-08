import 'package:flutter_test/flutter_test.dart';

class AppConfigDefaults {
  static const double defaultTaxRate = 15.0;
  static const String defaultCurrency = 'SAR';
  static const String defaultWarehouse = 'MAIN_WAREHOUSE';
  static const String defaultBranch = 'BRANCH-1';
}

class ConfigValueParser {
  static double? parseDouble(String? value) {
    if (value == null) return null;
    return double.tryParse(value);
  }

  static bool? parseBool(String? value) {
    if (value == null) return null;
    return value.toLowerCase() == 'true';
  }

  static T getWithDefault<T>(T? value, T defaultValue) {
    return value ?? defaultValue;
  }
}

void main() {
  group('AppConfigDefaults', () {
    test('default tax rate is correct', () {
      expect(AppConfigDefaults.defaultTaxRate, equals(15.0));
    });

    test('default currency is set', () {
      expect(AppConfigDefaults.defaultCurrency, isNotEmpty);
    });

    test('default warehouse is set', () {
      expect(AppConfigDefaults.defaultWarehouse, isNotEmpty);
    });
  });

  group('ConfigValueParser', () {
    test('parseDouble handles valid numbers', () {
      expect(ConfigValueParser.parseDouble('100'), equals(100.0));
      expect(ConfigValueParser.parseDouble('12.5'), equals(12.5));
      expect(ConfigValueParser.parseDouble('-5.5'), equals(-5.5));
    });

    test('parseDouble handles invalid input', () {
      expect(ConfigValueParser.parseDouble('abc'), isNull);
      expect(ConfigValueParser.parseDouble(''), isNull);
    });

    test('parseDouble handles null', () {
      expect(ConfigValueParser.parseDouble(null), isNull);
    });

    test('parseBool parses true values', () {
      expect(ConfigValueParser.parseBool('true'), isTrue);
      expect(ConfigValueParser.parseBool('TRUE'), isTrue);
      expect(ConfigValueParser.parseBool('True'), isTrue);
    });

    test('parseBool parses false values', () {
      expect(ConfigValueParser.parseBool('false'), isFalse);
      expect(ConfigValueParser.parseBool('FALSE'), isFalse);
    });

    test('parseBool handles invalid input', () {
      expect(ConfigValueParser.parseBool('yes'), isFalse);
      expect(ConfigValueParser.parseBool('no'), isFalse);
    });

    test('getWithDefault returns value if present', () {
      expect(ConfigValueParser.getWithDefault(100, 0), equals(100));
      expect(ConfigValueParser.getWithDefault('test', 'default'), equals('test'));
    });

    test('getWithDefault returns default if null', () {
      expect(ConfigValueParser.getWithDefault<String>(null, 'default'), equals('default'));
      expect(ConfigValueParser.getWithDefault<int>(null, 0), equals(0));
    });
  });

  group('Config Value Retrieval Patterns', () {
    test('integer config with default', () {
      String? storedValue = '50';
      final value = ConfigValueParser.parseDouble(storedValue);
      final result = ConfigValueParser.getWithDefault(value, 0);
      expect(result, equals(50.0));
    });

    test('missing config uses default', () {
      String? storedValue;
      final value = ConfigValueParser.parseDouble(storedValue);
      final result = ConfigValueParser.getWithDefault(value, AppConfigDefaults.defaultTaxRate);
      expect(result, equals(AppConfigDefaults.defaultTaxRate));
    });

    test('boolean config with default', () {
      String? storedValue = 'true';
      final value = ConfigValueParser.parseBool(storedValue);
      final result = ConfigValueParser.getWithDefault(value, false);
      expect(result, isTrue);
    });

    test('missing boolean uses default', () {
      String? storedValue;
      final value = ConfigValueParser.parseBool(storedValue);
      final result = ConfigValueParser.getWithDefault(value, false);
      expect(result, isFalse);
    });
  });
}
