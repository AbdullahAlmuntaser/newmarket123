import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class AppSettingsService {
  final AppDatabase db;

  AppSettingsService(this.db);

  Future<String?> getSetting(String key) async {
    final query = db.select(db.appConfigTable)..where((t) => t.key.equals(key));
    final setting = await query.getSingleOrNull();
    return setting?.value;
  }

  Future<void> setSetting(String key, String value,
      {String? description}) async {
    await db.into(db.appConfigTable).insertOnConflictUpdate(
          AppConfigTableCompanion(
            key: Value(key),
            value: Value(value),
            description: Value(description),
          ),
        );
  }

  // Helper methods for specific settings
  Future<String?> getCurrentBranchId() async =>
      await getSetting('current_branch_id');
  Future<void> setCurrentBranchId(String branchId) async =>
      await setSetting('current_branch_id', branchId);

  Future<String?> getCurrentWarehouseId() async =>
      await getSetting('current_warehouse_id');
  Future<void> setCurrentWarehouseId(String warehouseId) async =>
      await setSetting('current_warehouse_id', warehouseId);

  Future<double> getTaxRate() async {
    final rate = await getSetting('tax_rate');
    return rate != null ? double.parse(rate) : 0.15; // Default 15%
  }

  Future<void> setTaxRate(double rate) async =>
      await setSetting('tax_rate', rate.toString());
}
