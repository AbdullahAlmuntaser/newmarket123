import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:supermarket/core/services/app_config_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class DepreciationService {
  final AppDatabase db;
  late final AppConfigService _configService;

  DepreciationService(this.db) {
    _configService = AppConfigService(db);
  }

  static const String codeDepreciationExpense = '6001';
  static const String codeAccumulatedDepreciation = '1201';

  Future<void> runAutomaticDepreciation(DateTime asOfDate) async {
    final dao = db.accountingDao;
    final assets = await db.select(db.fixedAssets).get();
    final depreciationAccount =
        await dao.getAccountByCode(codeDepreciationExpense);
    final accumulatedDepAccount =
        await dao.getAccountByCode(codeAccumulatedDepreciation);

    if (depreciationAccount == null || accumulatedDepAccount == null) return;

    for (var asset in assets) {
      final costDecimal = Decimal.parse(asset.cost.toString());
      final salvageDecimal = Decimal.parse(asset.salvageValue.toString());
      final usefulLifeMonths = asset.usefulLifeYears * 12;
      final monthlyDepreciation =
          ((costDecimal - salvageDecimal) / Decimal.fromInt(usefulLifeMonths))
              .toDecimal(scaleOnInfinitePrecision: 3);

      final totalMonths = usefulLifeMonths;
      final accDepDecimal =
          Decimal.parse(asset.accumulatedDepreciation.toString());
      final alreadyDepreciatedMonths = accDepDecimal > Decimal.zero
          ? (accDepDecimal / monthlyDepreciation)
              .toDecimal(scaleOnInfinitePrecision: 0)
          : Decimal.zero;

      final elapsedDuration = asOfDate.difference(asset.purchaseDate);
      final elapsedMonths =
          Decimal.fromInt((elapsedDuration.inDays / 30).floor());

      var monthsToDepreciate = elapsedMonths - alreadyDepreciatedMonths;
      if (monthsToDepreciate <= Decimal.zero) continue;

      if (alreadyDepreciatedMonths + monthsToDepreciate >
          Decimal.fromInt(totalMonths)) {
        monthsToDepreciate =
            Decimal.fromInt(totalMonths) - alreadyDepreciatedMonths;
      }

      if (monthsToDepreciate <= Decimal.zero) continue;

      final depAmountDecimal = monthlyDepreciation * monthsToDepreciate;
      final entryId = const Uuid().v4();

      final branchId = await _getDefaultBranchId();

      final entry = GLEntriesCompanion.insert(
        id: Value(entryId),
        description:
            'إهلاك تلقائي للأصل: ${asset.name} لمدة $monthsToDepreciate شهر',
        date: Value(asOfDate),
        referenceType: const Value('DEPRECIATION'),
        referenceId: Value(asset.id.toString()),
        status: const Value('POSTED'),
        postedAt: Value(DateTime.now()),
        branchId: Value(branchId),
      );

      final lines = [
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: depreciationAccount.id,
          debit: Value(depAmountDecimal),
          credit: Value(Decimal.zero),
          branchId: Value(branchId),
        ),
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: accumulatedDepAccount.id,
          debit: Value(Decimal.zero),
          credit: Value(depAmountDecimal),
          branchId: Value(branchId),
        ),
      ];

      await dao.createEntry(entry, lines);

      await (db.update(db.fixedAssets)
        ..where((a) => a.id.equals(asset.id)))
          .write(
        FixedAssetsCompanion(
          accumulatedDepreciation: Value(
            accDepDecimal + depAmountDecimal,
          ),
        ),
      );
    }
  }

  Future<String> _getDefaultBranchId() async {
    return await _configService.getDefaultBranchId();
  }
}
