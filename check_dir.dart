
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'dart:developer' as developer;

void main() async {
  final db = AppDatabase();
  final dao = db.accountingDao;
  try {
    final accounts = await dao.getAllAccounts();
    if (accounts.isEmpty) {
      developer.log('No accounts found in the database.');
    } else {
      developer.log('--- List of Accounts ---');
      for (var account in accounts) {
        developer.log('Code: ${account.code}, Name: ${account.name}, Type: ${account.type}, ID: ${account.id}');
      }
      developer.log('--- End of List ---');
    }
  } catch (e) {
    developer.log('Error fetching accounts: $e');
  } finally {
    await db.close();
  }
}
