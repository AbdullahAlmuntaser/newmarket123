import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';
import 'accounting_service.dart';

class AssetService {
  final AppDatabase db;

  AssetService(this.db);

  Future<void> addAsset(FixedAssetsCompanion asset) async {
    await db.into(db.fixedAssets).insert(asset);
    
    // Optional: Auto-generate accounting entry for purchase
    // Debit: Asset Account, Credit: Cash/Bank
  }

  Future<List<FixedAsset>> getAllAssets() async {
    return await db.select(db.fixedAssets).get();
  }

  Future<void> processDepreciation() async {
    final assets = await getAllAssets();
    final dao = db.accountingDao;
    final entryId = const Uuid().v4();
    double totalDepreciation = 0;

    await db.transaction(() async {
      for (var asset in assets) {
        // Simple Monthly Straight-line Depreciation
        double monthlyDepreciation = (asset.cost - asset.salvageValue) / (asset.usefulLifeYears * 12);
        
        if (asset.accumulatedDepreciation + monthlyDepreciation > asset.cost) {
          monthlyDepreciation = asset.cost - asset.accumulatedDepreciation;
        }

        if (monthlyDepreciation > 0) {
          totalDepreciation += monthlyDepreciation;
          
          await (db.update(db.fixedAssets)..where((t) => t.id.equals(asset.id))).write(
            FixedAssetsCompanion(
              accumulatedDepreciation: Value(asset.accumulatedDepreciation + monthlyDepreciation),
            ),
          );
        }
      }

      if (totalDepreciation > 0) {
        // Accounting Entry
        // Debit: Depreciation Expense, Credit: Accumulated Depreciation (Contra-Asset)
        final entry = GLEntriesCompanion.insert(
          id: Value(entryId),
          description: 'Monthly Depreciation - ${DateTime.now().month}/${DateTime.now().year}',
          date: Value(DateTime.now()),
          referenceType: const Value('DEPRECIATION'),
        );

        final expenseAcc = await dao.getAccountByCode(AccountingService.codeExpenses);
        final assetAcc = await dao.getAccountByCode(AccountingService.codeFixedAssets);

        if (expenseAcc != null && assetAcc != null) {
          final lines = [
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: expenseAcc.id,
              debit: Value(totalDepreciation),
              credit: const Value(0.0),
            ),
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: assetAcc.id,
              debit: const Value(0.0),
              credit: Value(totalDepreciation),
            ),
          ];
          await dao.createEntry(entry, lines);
        }
      }
    });
  }
}
