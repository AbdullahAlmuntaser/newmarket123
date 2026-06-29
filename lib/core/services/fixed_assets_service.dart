import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

class FixedAssetsService {
  final AppDatabase db;

  FixedAssetsService(this.db);

  Future<Decimal> calculateMonthlyDepreciation(int assetId) async {
    final asset = await (db.select(db.fixedAssets)
          ..where((t) => t.id.equals(assetId)))
        .getSingle();

    Decimal depreciableAmount = asset.cost - asset.salvageValue;

    if (asset.depreciationMethod == 'straight_line') {
      return (depreciableAmount /
              (Decimal.fromInt(asset.usefulLifeYears) * Decimal.fromInt(12)))
          .toDecimal();
    } else if (asset.depreciationMethod == 'declining') {
      final Decimal annualRate =
          (Decimal.fromInt(2) / Decimal.fromInt(asset.usefulLifeYears))
              .toDecimal();
      final Decimal monthlyRate =
          (annualRate / Decimal.fromInt(12)).toDecimal();
      final Decimal bookValue = asset.cost - asset.accumulatedDepreciation;
      return bookValue * monthlyRate;
    }

    return Decimal.zero;
  }

  Future<List<Map<String, dynamic>>> runMonthlyDepreciation(
      DateTime runDate) async {
    final results = <Map<String, dynamic>>[];
    final assets = await (db.select(db.fixedAssets)
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

      if (depreciationAmount > Decimal.zero) {
        await db.into(db.accAssetDepreciationLogs).insert(
              AccAssetDepreciationLogsCompanion.insert(
                assetId: asset.id,
                depreciationAmount: depreciationAmount,
                depreciationDate: runDate,
              ),
            );

        await (db.update(db.fixedAssets)..where((t) => t.id.equals(asset.id)))
            .write(
          FixedAssetsCompanion(
            accumulatedDepreciation:
                Value(asset.accumulatedDepreciation + depreciationAmount),
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

  Future<String> _createDepreciationJournalEntry(
    int assetId,
    Decimal amount,
    DateTime date,
    int categoryId,
  ) async {
    final expenseAccountId = await _getDepreciationExpenseAccount(categoryId);
    final accumulatedDepreciationAccountId =
        await _getAccumulatedDepreciationAccount(assetId);

    final entryId = const Uuid().v4();
    final companion = GLEntriesCompanion.insert(
      description: 'قيد إهلاك شهرى للأصل',
      date: Value(date),
      referenceType: const Value('DEPRECIATION'),
      referenceId: Value('DEP-${date.toString().substring(0, 7)}-$assetId'),
      status: const Value('DRAFT'),
    ).copyWith(id: Value(entryId));

    await db.into(db.gLEntries).insert(companion);

    await db.batch((batch) {
      batch.insert(
        db.gLLines,
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: expenseAccountId,
          debit: Value(amount),
          credit: Value(Decimal.zero),
          memo: const Value('مصروف إهلاك'),
        ),
      );
      batch.insert(
        db.gLLines,
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: accumulatedDepreciationAccountId,
          debit: Value(Decimal.zero),
          credit: Value(amount),
          memo: const Value('مجمع إهلاك'),
        ),
      );
    });

    await _postGLEntry(entryId);

    return entryId;
  }

  Future<String> _getDepreciationExpenseAccount(int categoryId) async {
    // Try exact code first
    var account = await db.accountingDao.getAccountByCode('6001');
    if (account != null) return account.id;
    // Fall back to broader pattern
    final accounts = await (db.select(db.gLAccounts)
          ..where((t) => t.code.like('600%')))
        .get();
    if (accounts.isNotEmpty) return accounts.first.id;
    throw Exception('لم يتم العثور على حساب مصروف الإهلاك');
  }

  Future<String> _getAccumulatedDepreciationAccount(int assetId) async {
    // Try exact code first
    var account = await db.accountingDao.getAccountByCode('1201');
    if (account != null) return account.id;
    // Fall back to broader pattern
    final accounts = await (db.select(db.gLAccounts)
          ..where((t) => t.code.like('120%')))
        .get();
    if (accounts.isNotEmpty) return accounts.first.id;
    throw Exception('لم يتم العثور على حساب مجمع الإهلاك');
  }

  Future<Map<String, dynamic>> disposeAsset({
    required int assetId,
    required DateTime disposalDate,
    required String disposalType,
    double? salePrice,
    String? notes,
  }) async {
    final asset = await (db.select(db.fixedAssets)
          ..where((t) => t.id.equals(assetId)))
        .getSingle();

    Decimal bookValue = asset.cost - asset.accumulatedDepreciation;
    Decimal gainOrLoss = salePrice != null
        ? Decimal.parse(salePrice.toString()) - bookValue
        : -bookValue;

    final disposalId = await db.into(db.accAssetDisposals).insert(
          AccAssetDisposalsCompanion.insert(
            assetId: assetId,
            disposalDate: disposalDate,
            disposalType: disposalType,
            salePrice: Value(
                salePrice != null ? Decimal.parse(salePrice.toString()) : null),
            gainOrLoss: Value(gainOrLoss),
            notes: Value(notes),
          ),
        );

    final journalEntryId = await _createDisposalJournalEntry(
      assetId,
      bookValue,
      salePrice != null ? Decimal.parse(salePrice.toString()) : Decimal.zero,
      gainOrLoss,
      disposalDate,
      disposalType,
    );

    await (db.update(db.accAssetDisposals)
          ..where((t) => t.id.equals(disposalId)))
        .write(
      AccAssetDisposalsCompanion(journalEntryId: Value(journalEntryId)),
    );

    await (db.update(db.fixedAssets)..where((t) => t.id.equals(assetId))).write(
      FixedAssetsCompanion(
          status: Value(disposalType == 'sold' ? 'sold' : 'scrapped')),
    );

    return {
      'disposalId': disposalId,
      'journalEntryId': journalEntryId,
      'gainOrLoss': gainOrLoss,
      'bookValue': bookValue,
    };
  }

  Future<String> _createDisposalJournalEntry(
    int assetId,
    Decimal bookValue,
    Decimal salePrice,
    Decimal gainOrLoss,
    DateTime date,
    String disposalType,
  ) async {
    final asset = await (db.select(db.fixedAssets)
          ..where((t) => t.id.equals(assetId)))
        .getSingle();

    final accumulatedDepId = await _getAccumulatedDepreciationAccount(assetId);
    final cashBankId =
        disposalType == 'sold' ? await _getCashOrBankAccount() : '';
    final fixedAssetId = await _getFixedAssetAccount(assetId);
    String? gainLossId;
    if (gainOrLoss != Decimal.zero) {
      gainLossId = gainOrLoss > Decimal.zero
          ? await _getGainOnDisposalAccount()
          : await _getLossOnDisposalAccount();
    }

    final entryId = const Uuid().v4();
    final companion = GLEntriesCompanion.insert(
      description: 'قيد خروج أصل',
      date: Value(date),
      referenceType: const Value('DISPOSAL'),
      referenceId: Value('DISP-$disposalType-$assetId'),
      status: const Value('DRAFT'),
    ).copyWith(id: Value(entryId));

    await db.into(db.gLEntries).insert(companion);

    await db.batch((batch) {
      batch.insert(
        db.gLLines,
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: accumulatedDepId,
          debit: Value(asset.accumulatedDepreciation),
          credit: Value(Decimal.zero),
          memo: const Value('إلغاء مجمع الإهلاك'),
        ),
      );

      if (disposalType == 'sold' && salePrice > Decimal.zero) {
        batch.insert(
          db.gLLines,
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: cashBankId,
            debit: Value(salePrice),
            credit: Value(Decimal.zero),
            memo: const Value('تحصيل بيع الأصل'),
          ),
        );
      }

      batch.insert(
        db.gLLines,
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: fixedAssetId,
          debit: Value(Decimal.zero),
          credit: Value(asset.cost),
          memo: const Value('إلغاء قيمة الأصل'),
        ),
      );

      if (gainOrLoss != Decimal.zero && gainLossId != null) {
        batch.insert(
          db.gLLines,
          GLLinesCompanion.insert(
            entryId: entryId,
            accountId: gainLossId,
            debit:
                Value(gainOrLoss > Decimal.zero ? Decimal.zero : -gainOrLoss),
            credit:
                Value(gainOrLoss > Decimal.zero ? gainOrLoss : Decimal.zero),
            memo: Value(
                gainOrLoss > Decimal.zero ? 'ربح بيع أصل' : 'خسارة بيع أصل'),
          ),
        );
      }
    });

    await _postGLEntry(entryId);

    return entryId;
  }

  Future<String> _getCashOrBankAccount() async {
    var account = await db.accountingDao.getAccountByCode('1010');
    if (account != null) return account.id;
    final accounts = await (db.select(db.gLAccounts)
          ..where((t) => t.code.like('101%')))
        .get();
    if (accounts.isEmpty) throw Exception('لم يتم العثور على حساب الصندوق');
    return accounts.first.id;
  }

  Future<String> _getFixedAssetAccount(int assetId) async {
    var account = await db.accountingDao.getAccountByCode('1200');
    if (account != null) return account.id;
    final accounts = await (db.select(db.gLAccounts)
          ..where((t) => t.code.like('120%')))
        .get();
    if (accounts.isEmpty) {
      throw Exception('لم يتم العثور على حساب الأصول الثابتة');
    }
    return accounts.first.id;
  }

  Future<String> _getGainOnDisposalAccount() async {
    var account = await db.accountingDao.getAccountByCode('4010');
    if (account != null) return account.id;
    final accounts = await (db.select(db.gLAccounts)
          ..where((t) => t.code.like('401%')))
        .get();
    if (accounts.isEmpty) throw Exception('لم يتم العثور على حساب الإيرادات');
    return accounts.first.id;
  }

  Future<String> _getLossOnDisposalAccount() async {
    var account = await db.accountingDao.getAccountByCode('6001');
    if (account != null) return account.id;
    final accounts = await (db.select(db.gLAccounts)
          ..where((t) => t.code.like('600%')))
        .get();
    if (accounts.isEmpty) throw Exception('لم يتم العثور على حساب المصروفات');
    return accounts.first.id;
  }

  Future<void> _postGLEntry(String entryId) async {
    await (db.update(db.gLEntries)..where((t) => t.id.equals(entryId))).write(
      GLEntriesCompanion(
        status: const Value('POSTED'),
        postedAt: Value(DateTime.now()),
      ),
    );
  }
}
