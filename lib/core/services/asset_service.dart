import 'package:drift/drift.dart';
import 'package:supermarket/core/constants/account_codes.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

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
    Decimal totalDepreciation = Decimal.zero;

    await db.transaction(() async {
      for (var asset in assets) {
        // Simple Monthly Straight-line Depreciation
        // Asset uses Decimal internally in Drift if configured correctly via DecimalConverter
        final cost = Decimal.parse(asset.cost.toString());
        final salvageValue = Decimal.parse(asset.salvageValue.toString());
        final accumulatedDepreciation =
            Decimal.parse(asset.accumulatedDepreciation.toString());

        Decimal monthlyDepreciation = ((cost - salvageValue) /
                Decimal.fromInt(asset.usefulLifeYears * 12))
            .toDecimal();

        if (accumulatedDepreciation + monthlyDepreciation >
            cost - salvageValue) {
          monthlyDepreciation = (cost - salvageValue) - accumulatedDepreciation;
        }

        if (monthlyDepreciation > Decimal.zero) {
          totalDepreciation += monthlyDepreciation;

          await (db.update(
            db.fixedAssets,
          )..where((t) => t.id.equals(asset.id)))
              .write(
            FixedAssetsCompanion(
              accumulatedDepreciation: Value(
                accumulatedDepreciation + monthlyDepreciation,
              ),
            ),
          );
        }
      }

      if (totalDepreciation > Decimal.zero) {
        // Accounting Entry
        // Debit: Depreciation Expense, Credit: Accumulated Depreciation (Contra-Asset)
        final entry = GLEntriesCompanion.insert(
          id: Value(entryId),
          description:
              'إهلاك شهري - ${DateTime.now().month}/${DateTime.now().year}',
          date: Value(DateTime.now()),
          referenceType: const Value('DEPRECIATION'),
        );

        // We need the specific expense and contra-asset accounts
        final expenseAccount = await dao.getAccountByCode(
          AccountCodes.depreciationExpense,
        );
        final contraAssetAccount = await dao.getAccountByCode(
          AccountCodes.accumulatedDepreciation,
        );

        if (expenseAccount != null && contraAssetAccount != null) {
          final lines = [
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: expenseAccount.id,
              debit: Value(totalDepreciation),
              credit: Value(Decimal.zero),
            ),
            GLLinesCompanion.insert(
              entryId: entryId,
              accountId: contraAssetAccount.id,
              debit: Value(Decimal.zero),
              credit: Value(totalDepreciation),
            ),
          ];
          await dao.createEntry(entry, lines);
        } else {
          // This is a critical setup issue. We should throw an exception to rollback the transaction.
          throw Exception(
            'حسابات الإهلاك غير معرفة. الرجاء إعداد حساب المصروف (6001) وحساب الإهلاك المتراكم (1201) في شجرة الحسابات.',
          );
        }
      }
    });
  }
}
