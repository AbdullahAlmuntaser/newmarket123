import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/core/services/security_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart' as di;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SecurityService.useFakeKeyForTesting = true;

  group('Full Initialization Simulation', () {
    test('Simulates complete app initialization flow', () async {
      final stopwatch = Stopwatch()..start();
      await di.init();
      final db = di.sl<AppDatabase>();
      await db.select(db.users).get();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(30000),
          reason: 'Full initialization should complete within 30 seconds');

      await db.close();
    }, skip: 'Requires path_provider platform channel - run on device');

    test('Measures beforeOpen callback performance', () async {
      final db1 = AppDatabase(NativeDatabase.memory());
      var stopwatch = Stopwatch()..start();
      await db1.select(db1.users).get();
      stopwatch.stop();
      final freshTime = stopwatch.elapsedMilliseconds;
      await db1.close();

      final db2 = AppDatabase(NativeDatabase.memory());
      await db2.select(db2.users).get();
      await db2.close();

      final db3 = AppDatabase(NativeDatabase.memory());
      stopwatch = Stopwatch()..start();
      await db3.select(db3.users).get();
      stopwatch.stop();
      final existingTime = stopwatch.elapsedMilliseconds;
      await db3.close();

      expect(freshTime, lessThan(5000));
      expect(existingTime, lessThan(5000));
    });

    test('Measures _recoverMissingTables performance', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.select(db.users).get();

      final stopwatch = Stopwatch()..start();
      for (final table in db.allTables) {
        await db.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='${table.actualTableName}'",
        ).getSingleOrNull();
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(2000));

      await db.close();
    });

    test('Measures ensurePerformanceIndexes performance', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.select(db.users).get();

      final indexes = await db.customSelect(
        "SELECT COUNT(*) as cnt FROM sqlite_master WHERE type='index'",
      ).get();
      final indexCount = indexes.first.data['cnt'] as int;
      expect(indexCount, greaterThan(0));

      await db.close();
    });

    test('Measures seed data performance', () async {
      final db = AppDatabase(NativeDatabase.memory());

      final stopwatch = Stopwatch()..start();
      await db.select(db.users).get();
      stopwatch.stop();

      final currencies = await db.select(db.currencies).get();
      final branches = await db.select(db.branches).get();
      final glAccounts = await db.select(db.gLAccounts).get();
      final permissions = await db.select(db.permissions).get();

      expect(currencies.length, greaterThanOrEqualTo(1));
      expect(branches.length, greaterThanOrEqualTo(1));
      expect(glAccounts.length, greaterThanOrEqualTo(1));
      expect(permissions.length, greaterThanOrEqualTo(1));

      await db.close();
    });

    test('Multiple sequential opens simulate app restarts', () async {
      final times = <int>[];

      for (var i = 0; i < 5; i++) {
        final db = AppDatabase(NativeDatabase.memory());
        final stopwatch = Stopwatch()..start();
        await db.select(db.users).get();
        stopwatch.stop();
        times.add(stopwatch.elapsedMilliseconds);
        await db.close();
      }

      expect(times.every((t) => t < 5000), isTrue);
    });
  });
}
