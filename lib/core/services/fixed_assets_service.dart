import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class FixedAssetsService {
  final AppDatabase db;

  FixedAssetsService(this.db);

  Future<double> calculateMonthlyDepreciation(int assetId) async {
    final asset = await (db.select(db.accFixedAssets)
          ..where((t) => t.id.equals(assetId)))
        .getSingle();

    double depreciableAmount = asset.purchaseCost - asset.salvageValue;

    if (asset.depreciationMethod == 'straight_line') {
      return depreciableAmount / asset.usefulLifeMonths;
    } else if (asset.depreciationMethod == 'declining') {
      final annualRate = 2.0 / asset.usefulLifeMonths * 12;
      final monthlyRate = annualRate / 12;
      final bookValue = asset.purchaseCost - asset.accumulatedDepreciation;
      return bookValue * monthlyRate;
    }

    return 0.0;
  }

  Future<List<Map<String, dynamic>>> runMonthlyDepreciation(
      DateTime runDate) async {
    final results = <Map<String, dynamic>>[];
    final assets = await (db.select(db.accFixedAssets)
          ..where((t) => t.status.equals('active')))
        .get();

    for (var asset in assets) {
      if (asset.lastDepreciationDate != null) {
        final lastRun = asset.lastDepreciationDate!;
        if (runDate.month == lastRun.month && runDate.year == lastRun.year) {
          continue;
        }
      }

      final depreciationAmount = await calculateMonthlyDepreciation(asset.id);

      if (depreciationAmount > 0) {
        await db.into(db.accAssetDepreciationLogs).insert(
              AccAssetDepreciationLogsCompanion.insert(
                assetId: asset.id,
                depreciationAmount: depreciationAmount,
                depreciationDate: runDate,
              ),
            );

        await (db.update(db.accFixedAssets)
              ..where((t) => t.id.equals(asset.id)))
            .write(
          AccFixedAssetsCompanion(
            accumulatedDepreciation: Value(
                (asset.accumulatedDepreciation + depreciationAmount).toInt()),
            lastDepreciationDate: Value(runDate),
          ),
        );

        final journalEntryId = await _createDepreciationJournalEntry(
          asset.id,
          depreciationAmount,
          runDate,
          asset.categoryId,
        );

        final log = await (db.select(db.accAssetDepreciationLogs)
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingle();
        await (db.update(db.accAssetDepreciationLogs)
              ..where((t) => t.id.equals(log.id)))
            .write(
          AccAssetDepreciationLogsCompanion(
              journalEntryId: Value(journalEntryId)),
        );

        results.add({
          'assetId': asset.id,
          'assetName': asset.name,
          'depreciationAmount': depreciationAmount,
          'journalEntryId': journalEntryId,
        });
      }
    }

    return results;
  }

  Future<int> _createDepreciationJournalEntry(
    int assetId,
    double amount,
    DateTime date,
    int categoryId,
  ) async {
    final expenseAccountId = await _getDepreciationExpenseAccount(categoryId);
    final accumulatedDepreciationAccountId =
        await _getAccumulatedDepreciationAccount(assetId);

    final entryId = await db.into(db.gLEntries).insert(
          GLEntriesCompanion.insert(
            description: 'قيد إهلاك شهرى للأصل',
            date: Value(date),
            referenceType: const Value('DEPRECIATION'),
            referenceId:
                Value('DEP-${date.toString().substring(0, 7)}-$assetId'),
            status: const Value('DRAFT'),
          ),
        );

    await db.batch((batch) {
      batch.insert(
          db.gLLines,
          GLLinesCompanion.insert(
            entryId: entryId.toString(),
            accountId: expenseAccountId,
            debit: Value(amount),
            credit: const Value(0.0),
            memo: const Value('مصروف إهلاك'),
          ));
      batch.insert(
          db.gLLines,
          GLLinesCompanion.insert(
            entryId: entryId.toString(),
            accountId: accumulatedDepreciationAccountId,
            debit: const Value(0.0),
            credit: Value(amount),
            memo: const Value('مجمع إهلاك'),
          ));
    });

    await _postGLEntry(entryId);

    return entryId;
  }

  Future<String> _getDepreciationExpenseAccount(int categoryId) async {
    final accounts =
        await (db.select(db.gLAccounts)..where((t) => t.code.like('6%'))).get();

    if (accounts.isNotEmpty) {
      return accounts.first.id;
    }
    throw Exception('لم يتم العثور على حساب مصروف الإهلاك');
  }

  Future<String> _getAccumulatedDepreciationAccount(int assetId) async {
    final accounts = await (db.select(db.gLAccounts)
          ..where((t) => t.code.like('16%')))
        .get();

    if (accounts.isNotEmpty) {
      return accounts.first.id;
    }
    throw Exception('لم يتم العثور على حساب مجمع الإهلاك');
  }

  Future<Map<String, dynamic>> disposeAsset({
    required int assetId,
    required DateTime disposalDate,
    required String disposalType,
    double? salePrice,
    String? notes,
  }) async {
    final asset = await (db.select(db.accFixedAssets)
          ..where((t) => t.id.equals(assetId)))
        .getSingle();

    double bookValue = asset.purchaseCost - asset.accumulatedDepreciation;
    double gainOrLoss = salePrice != null ? salePrice - bookValue : -bookValue;

    final disposalId = await db.into(db.accAssetDisposals).insert(
          AccAssetDisposalsCompanion.insert(
            assetId: assetId,
            disposalDate: disposalDate,
            disposalType: disposalType,
            salePrice: Value(salePrice),
            gainOrLoss: Value(gainOrLoss),
            notes: Value(notes),
          ),
        );

    final journalEntryId = await _createDisposalJournalEntry(
      assetId,
      bookValue,
      salePrice ?? 0,
      gainOrLoss,
      disposalDate,
      disposalType,
    );

    await (db.update(db.accAssetDisposals)
          ..where((t) => t.id.equals(disposalId)))
        .write(
      AccAssetDisposalsCompanion(journalEntryId: Value(journalEntryId)),
    );

    await (db.update(db.accFixedAssets)..where((t) => t.id.equals(assetId)))
        .write(
      AccFixedAssetsCompanion(
          status: Value(disposalType == 'sold' ? 'sold' : 'scrapped')),
    );

    return {
      'disposalId': disposalId,
      'journalEntryId': journalEntryId,
      'gainOrLoss': gainOrLoss,
      'bookValue': bookValue,
    };
  }

  Future<int> _createDisposalJournalEntry(
    int assetId,
    double bookValue,
    double salePrice,
    double gainOrLoss,
    DateTime date,
    String disposalType,
  ) async {
    final asset = await (db.select(db.accFixedAssets)
          ..where((t) => t.id.equals(assetId)))
        .getSingle();

    final accumulatedDepId = await _getAccumulatedDepreciationAccount(assetId);
    final cashBankId =
        disposalType == 'sold' ? await _getCashOrBankAccount() : '';
    final fixedAssetId = await _getFixedAssetAccount(assetId);
    String? gainLossId;
    if (gainOrLoss != 0) {
      gainLossId = gainOrLoss > 0
          ? await _getGainOnDisposalAccount()
          : await _getLossOnDisposalAccount();
    }

    final entryId = await db.into(db.gLEntries).insert(
          GLEntriesCompanion.insert(
            description: 'قيد خروج أصل',
            date: Value(date),
            referenceType: const Value('DISPOSAL'),
            referenceId: Value('DISP-$disposalType-$assetId'),
            status: const Value('DRAFT'),
          ),
        );

    await db.batch((batch) {
      batch.insert(
          db.gLLines,
          GLLinesCompanion.insert(
            entryId: entryId.toString(),
            accountId: accumulatedDepId,
            debit: Value(asset.accumulatedDepreciation.toDouble()),
            credit: const Value(0.0),
            memo: const Value('إلغاء مجمع الإهلاك'),
          ));

      if (disposalType == 'sold' && salePrice > 0) {
        batch.insert(
            db.gLLines,
            GLLinesCompanion.insert(
              entryId: entryId.toString(),
              accountId: cashBankId,
              debit: Value(salePrice),
              credit: const Value(0.0),
              memo: const Value('تحصيل بيع الأصل'),
            ));
      }

      batch.insert(
          db.gLLines,
          GLLinesCompanion.insert(
            entryId: entryId.toString(),
            accountId: fixedAssetId,
            debit: const Value(0.0),
            credit: Value(asset.purchaseCost),
            memo: const Value('إلغاء قيمة الأصل'),
          ));

      if (gainOrLoss != 0 && gainLossId != null) {
        batch.insert(
            db.gLLines,
            GLLinesCompanion.insert(
              entryId: entryId.toString(),
              accountId: gainLossId,
              debit: Value(gainOrLoss > 0 ? 0.0 : -gainOrLoss),
              credit: Value(gainOrLoss > 0 ? gainOrLoss : 0.0),
              memo: Value(gainOrLoss > 0 ? 'ربح بيع أصل' : 'خسارة بيع أصل'),
            ));
      }
    });

    await _postGLEntry(entryId);

    return entryId;
  }

  Future<String> _getCashOrBankAccount() async {
    final accounts = await (db.select(db.gLAccounts)
          ..where((t) => t.code.like('10%')))
        .get();
    if (accounts.isEmpty) throw Exception('لم يتم العثور على حساب الصندوق');
    return accounts.first.id;
  }

  Future<String> _getFixedAssetAccount(int assetId) async {
    final accounts = await (db.select(db.gLAccounts)
          ..where((t) => t.code.like('15%')))
        .get();
    if (accounts.isEmpty) {
      throw Exception('لم يتم العثور على حساب الأصول الثابتة');
    }
    return accounts.first.id;
  }

  Future<String> _getGainOnDisposalAccount() async {
    final accounts =
        await (db.select(db.gLAccounts)..where((t) => t.code.like('4%'))).get();
    if (accounts.isEmpty) throw Exception('لم يتم العثور على حساب الإيرادات');
    return accounts.first.id;
  }

  Future<String> _getLossOnDisposalAccount() async {
    final accounts =
        await (db.select(db.gLAccounts)..where((t) => t.code.like('6%'))).get();
    if (accounts.isEmpty) throw Exception('لم يتم العثور على حساب المصروفات');
    return accounts.first.id;
  }

  Future<void> _postGLEntry(int entryId) async {
    await (db.update(db.gLEntries)
          ..where((t) => t.id.equals(entryId.toString())))
        .write(
      GLEntriesCompanion(
        status: const Value('POSTED'),
        postedAt: Value(DateTime.now()),
      ),
    );
  }
}
