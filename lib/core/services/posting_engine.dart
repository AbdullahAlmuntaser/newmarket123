import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

enum TransactionType { sale, purchase, returnSale, returnPurchase, paymentIn, paymentOut }

class PostingEngine {
  final AppDatabase db;

  PostingEngine(this.db);

  Future<void> post({
    required TransactionType type,
    required String referenceId,
    required Map<String, dynamic> context,
  }) async {
    // 1. Period Lock Check (Mandatory)
    await _checkPeriodOpen();

    // 2. Load Posting Profile
    final profile = await (db.select(db.postingProfiles)
          ..where((p) => p.operationType.equals(type.name))
          ..where((p) => p.isActive.equals(true)))
        .get();

    if (profile.isEmpty) throw Exception('No posting profile found for $type');

    // 3. Create Journal Entry
    final entryId = const Uuid().v4();
    final entry = GLEntriesCompanion.insert(
      id: Value(entryId),
      description: context['description'] ?? 'Transaction: $type',
      date: Value(DateTime.now()),
      referenceType: Value(type.name),
      referenceId: Value(referenceId),
      status: const Value('POSTED'),
    );

    List<GLLinesCompanion> lines = [];
    for (var p in profile) {
      if (p.accountId == null) continue;
      
      lines.add(GLLinesCompanion.insert(
        entryId: entryId,
        accountId: p.accountId!,
        debit: Value(p.side == 'DEBIT' ? (context['amount'] ?? 0.0) : 0.0),
        credit: Value(p.side == 'CREDIT' ? (context['amount'] ?? 0.0) : 0.0),
      ));
    }

    // 4. Validate Balance
    double totalDebit = lines.fold(0, (sum, l) => sum + (l.debit.value));
    double totalCredit = lines.fold(0, (sum, l) => sum + (l.credit.value));
    
    if ((totalDebit - totalCredit).abs() > 0.01) {
      throw Exception('Journal Entry unbalanced: Dr $totalDebit, Cr $totalCredit');
    }

    // 5. Execute Transaction
    await db.accountingDao.createEntry(entry, lines);
  }

  Future<void> _checkPeriodOpen() async {
    final now = DateTime.now();
    final period = await (db.select(db.accountingPeriods)
          ..where((p) => p.isClosed.equals(false))
          ..where((p) => p.startDate.isSmallerOrEqualValue(now))
          ..where((p) => p.endDate.isBiggerOrEqualValue(now)))
        .getSingleOrNull();

    if (period == null) throw Exception('Period is locked or closed.');
  }
}
