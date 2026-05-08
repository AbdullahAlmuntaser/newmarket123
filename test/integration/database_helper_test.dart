import 'package:flutter_test/flutter_test.dart';

class DatabaseHelper {
  static int _counter = 0;
  static String generateId() {
    _counter++;
    return '${DateTime.now().millisecondsSinceEpoch}_$_counter';
  }

  static bool isUuid(String id) {
    return id.length > 20;
  }
}

class DateHelper {
  static bool isCurrentPeriod(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year;
  }

  static bool isInClosedPeriod(DateTime date, List<Map<String, dynamic>> closedPeriods) {
    for (var period in closedPeriods) {
      final start = period['startDate'] as DateTime;
      final end = period['endDate'] as DateTime;
      if (date.isAfter(start) && date.isBefore(end)) {
        return true;
      }
    }
    return false;
  }
}

void main() {
  group('DatabaseHelper', () {
    test('generates unique IDs', () {
      final id1 = DatabaseHelper.generateId();
      final id2 = DatabaseHelper.generateId();
      expect(id1, isNot(equals(id2)));
    });

    test('ID format is string', () {
      final id = DatabaseHelper.generateId();
      expect(id, isA<String>());
      expect(id.isNotEmpty, isTrue);
    });

    test('ID length is reasonable', () {
      final id = DatabaseHelper.generateId();
      expect(id.length, greaterThan(10));
    });
  });

  group('DateHelper', () {
    test('current date is in current period', () {
      expect(DateHelper.isCurrentPeriod(DateTime.now()), isTrue);
    });

    test('past date is not in current period', () {
      expect(DateHelper.isCurrentPeriod(DateTime(2020, 1, 1)), isFalse);
    });

    test('detects closed period', () {
      final closedPeriods = [
        {
          'startDate': DateTime(2024, 1, 1),
          'endDate': DateTime(2024, 12, 31),
        },
      ];

      expect(
        DateHelper.isInClosedPeriod(DateTime(2024, 6, 15), closedPeriods),
        isTrue,
      );
    });

    test('date outside closed period', () {
      final closedPeriods = [
        {
          'startDate': DateTime(2024, 1, 1),
          'endDate': DateTime(2024, 12, 31),
        },
      ];

      expect(
        DateHelper.isInClosedPeriod(DateTime(2023, 6, 15), closedPeriods),
        isFalse,
      );
    });
  });
}
