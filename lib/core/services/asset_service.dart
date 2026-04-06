import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';
import 'accounting_service.dart';

class AssetService {
  final AppDatabase db;

  AssetService(this.db);

  Future<void> addAsset(Insertable<FixedAsset> asset) async {
    await db.into(db.fixedAssets).insert(asset);
  }

  Future<void> updateAsset(Insertable<FixedAsset> asset) async {
    await db.update(db.fixedAssets).replace(asset);
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

        if (asset.accumulatedDepreciation + monthlyDepreciation > asset.cost - asset.salvageValue) {
          monthlyDepreciation = (asset.cost - asset.salvageValue) - asset.accumulatedDepreciation;
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
          description: 'إهلاك شهري - ${DateTime.now().month}/${DateTime.now().year}',
          date: Value(DateTime.now()),
          referenceType: const Value('DEPRECIATION'),
        );

        // We need the specific expense and contra-asset accounts
        final expenseAccount = await dao.getAccountByCode(AccountingService.codeDepreciationExpense);
        final contraAssetAccount = await dao.getAccountByCode(AccountingService.codeAccumulatedDepreciation);

        if (expenseAccount != null && contraAssetAccount != null) {
          final lines = [
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: expenseAccount.id,
              debit: Value(totalDepreciation),
            ),
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: contraAssetAccount.id,
              credit: Value(totalDepreciation),
            ),
          ];
          await dao.createEntry(entry, lines);
        } else {
          // This is a critical setup issue. We should throw an exception to rollback the transaction.
          throw Exception('حسابات الإهلاك غير معرفة. الرجاء إعداد حساب المصروف (6001) وحساب الإهلاك المتراكم (1201) في شجرة الحسابات.');
        }
      }
    });
  }
}
