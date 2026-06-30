import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/recurring_entry_dao.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'posting_engine.dart';

class RecurringEntryService {
  final AppDatabase db;
  final PostingEngine postingEngine;
  late final RecurringEntryDao _dao;

  RecurringEntryService(this.db, {PostingEngine? postingEngine})
      : postingEngine = postingEngine ?? PostingEngine(db) {
    _dao = db.recurringEntryDao;
  }

  // CRUD Operations
  Future<List<RecurringEntry>> getAllEntries() => _dao.getAllRecurringEntries();
  Stream<List<RecurringEntry>> watchAllEntries() =>
      _dao.watchAllRecurringEntries();
  Future<RecurringEntry?> getEntry(int id) =>
      _dao.getRecurringEntryById(id);

  Future<int> createEntry({
    required String name,
    String? description,
    required String referenceType,
    required String frequency,
    required String debitAccountCode,
    required String creditAccountCode,
    required Decimal amount,
    String? costCenterId,
    String? branchId,
    required DateTime startDate,
    DateTime? endDate,
    int? maxExecutions,
    String? createdBy,
  }) async {
    final nextDate = _calculateNextDate(startDate, frequency);
    return _dao.createRecurringEntry(
      RecurringEntriesCompanion.insert(
        name: name,
        description: Value(description),
        referenceType: referenceType,
        frequency: frequency,
        debitAccountCode: debitAccountCode,
        creditAccountCode: creditAccountCode,
        amount: amount,
        costCenterId: Value(costCenterId),
        branchId: Value(branchId),
        startDate: startDate,
        endDate: Value(endDate),
        nextExecutionDate: nextDate,
        maxExecutions: Value(maxExecutions),
        createdBy: Value(createdBy),
      ),
    );
  }

  Future<bool> updateEntry(RecurringEntry entry) =>
      _dao.updateRecurringEntry(entry);

  Future<int> deleteEntry(int id) => _dao.deleteRecurringEntry(id);

  Future<void> pauseEntry(int id) => _dao.pauseRecurringEntry(id);
  Future<void> resumeEntry(int id) => _dao.resumeRecurringEntry(id);

  // Execute all due entries
  Future<RecurringExecutionResult> executeDueEntries() async {
    final dueEntries = await _dao.getActiveRecurringEntries();
    int successCount = 0;
    int failCount = 0;
    final errors = <String>[];

    for (final entry in dueEntries) {
      try {
        await _executeEntry(entry);
        successCount++;
      } catch (e) {
        failCount++;
        errors.add('${entry.name}: $e');

        await _dao.logExecution(
          RecurringEntryExecutionsCompanion.insert(
            recurringEntryId: entry.id,
            glEntryId: '',
            executionDate: DateTime.now(),
            status: const Value('failed'),
            errorMessage: Value(e.toString()),
          ),
        );
      }
    }

    return RecurringExecutionResult(
      totalProcessed: dueEntries.length,
      successCount: successCount,
      failCount: failCount,
      errors: errors,
    );
  }

  // Execute a single entry
  Future<void> _executeEntry(RecurringEntry entry) async {
    if (entry.status != 'active') return;

    if (entry.endDate != null && DateTime.now().isAfter(entry.endDate!)) {
      await _dao.completeRecurringEntry(entry.id);
      return;
    }

    if (entry.maxExecutions != null &&
        entry.totalExecutions >= entry.maxExecutions!) {
      await _dao.completeRecurringEntry(entry.id);
      return;
    }

    final referenceId =
        'RECURRING-${entry.id}-${DateTime.now().millisecondsSinceEpoch}';

    await postingEngine.post(
      type: TransactionType.cashReceipt,
      referenceId: referenceId,
      context: {
        'amount': entry.amount,
        'debitAccountId': entry.debitAccountCode,
        'creditAccountId': entry.creditAccountCode,
        'description': '${entry.name} - تنفيذ دوري #${entry.totalExecutions + 1}',
        'date': DateTime.now(),
        'referenceType': entry.referenceType,
        'branchId': entry.branchId,
        'costCenterId': entry.costCenterId,
      },
    );

    await _logSuccessfulExecution(entry, referenceId);

    final nextDate = _calculateNextDate(entry.nextExecutionDate, entry.frequency);
    await _dao.updateNextExecutionDate(entry.id, nextDate);
    await _dao.incrementExecutionCount(entry.id);
  }

  Future<void> _logSuccessfulExecution(
      RecurringEntry entry, String glEntryId) async {
    await _dao.logExecution(
      RecurringEntryExecutionsCompanion.insert(
        recurringEntryId: entry.id,
        glEntryId: glEntryId,
        executionDate: DateTime.now(),
        status: const Value('posted'),
      ),
    );
  }

  // Preview what will be executed
  Future<List<RecurringEntryPreview>> previewDueEntries() async {
    final dueEntries = await _dao.getActiveRecurringEntries();
    return dueEntries.map((entry) {
      return RecurringEntryPreview(
        entry: entry,
        nextExecutionDate: entry.nextExecutionDate,
        estimatedAmount: entry.amount,
        executionNumber: entry.totalExecutions + 1,
      );
    }).toList();
  }

  // Manual execution
  Future<void> executeEntryNow(int entryId) async {
    final entry = await _dao.getRecurringEntryById(entryId);
    if (entry == null) throw Exception('القيد الدوري غير موجود.');
    if (entry.status != 'active') throw Exception('القيد الدوري غير نشط.');
    await _executeEntry(entry);
  }

  // Get execution history
  Future<List<RecurringEntryExecution>> getExecutionHistory(int entryId) =>
      _dao.getExecutionsForEntry(entryId);

  Future<List<RecurringEntryExecution>> getRecentExecutions({int limit = 50}) =>
      _dao.getRecentExecutions(limit: limit);

  // Statistics
  Future<RecurringStats> getStats() async {
    final all = await _dao.getAllRecurringEntries();
    final active = all.where((e) => e.status == 'active').length;
    final paused = all.where((e) => e.status == 'paused').length;
    final completed = all.where((e) => e.status == 'completed').length;
    final totalExecutions =
        all.fold<int>(0, (sum, e) => sum + e.totalExecutions);

    return RecurringStats(
      totalEntries: all.length,
      activeEntries: active,
      pausedEntries: paused,
      completedEntries: completed,
      totalExecutions: totalExecutions,
    );
  }

  // Helper: Calculate next execution date based on frequency
  DateTime _calculateNextDate(DateTime current, String frequency) {
    switch (frequency.toUpperCase()) {
      case 'DAILY':
        return current.add(const Duration(days: 1));
      case 'WEEKLY':
        return current.add(const Duration(days: 7));
      case 'BIWEEKLY':
        return current.add(const Duration(days: 14));
      case 'MONTHLY':
        return _addMonths(current, 1);
      case 'QUARTERLY':
        return _addMonths(current, 3);
      case 'YEARLY':
        return _addMonths(current, 12);
      default:
        return current.add(const Duration(days: 30));
    }
  }

  DateTime _addMonths(DateTime date, int months) {
    int newMonth = date.month + months;
    int newYear = date.year;
    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }
    int newDay = date.day;
    final lastDay = DateTime(newYear, newMonth + 1, 0).day;
    if (newDay > lastDay) newDay = lastDay;
    return DateTime(newYear, newMonth, newDay, date.hour, date.minute);
  }
}

class RecurringExecutionResult {
  final int totalProcessed;
  final int successCount;
  final int failCount;
  final List<String> errors;

  RecurringExecutionResult({
    required this.totalProcessed,
    required this.successCount,
    required this.failCount,
    required this.errors,
  });
}

class RecurringEntryPreview {
  final RecurringEntry entry;
  final DateTime nextExecutionDate;
  final Decimal estimatedAmount;
  final int executionNumber;

  RecurringEntryPreview({
    required this.entry,
    required this.nextExecutionDate,
    required this.estimatedAmount,
    required this.executionNumber,
  });
}

class RecurringStats {
  final int totalEntries;
  final int activeEntries;
  final int pausedEntries;
  final int completedEntries;
  final int totalExecutions;

  RecurringStats({
    required this.totalEntries,
    required this.activeEntries,
    required this.pausedEntries,
    required this.completedEntries,
    required this.totalExecutions,
  });
}
