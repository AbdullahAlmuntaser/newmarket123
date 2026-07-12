
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

void main() {
  test('Fetch and print all GL accounts', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final db = AppDatabase(NativeDatabase.memory());
    final dao = db.accountingDao;

    try {
      final accounts = await dao.getAllAccounts();
      if (accounts.isEmpty) {
        debugPrint('No accounts found in the database.');
      } else {
        debugPrint('--- List of Accounts ---');
        for (var account in accounts) {
          debugPrint('Code: ${account.code}, Name: ${account.name}, Type: ${account.type}, ID: ${account.id}');
        }
        debugPrint('--- End of List ---');
      }
    } catch (e, s) {
      debugPrint('Error fetching accounts: $e');
      debugPrint('Stacktrace: $s');
    } finally {
      await db.close();
    }
  });
}
