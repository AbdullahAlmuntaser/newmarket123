import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

/// خدمة سجل التدقيقات - تسجل جميع العمليات الحساسة في النظام
class AuditLogService {
  final AppDatabase db;

  AuditLogService(this.db);

  /// تسجيل عملية
  Future<void> logAction({
    required String userId,
    required String action,
    required String logTableName,
    required String recordId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    await db.into(db.accAuditLogs).insert(
          AccAuditLogsCompanion.insert(
            logTableName: logTableName,
            recordId: recordId,
            action: action,
            oldValues: Value(oldValues != null ? jsonEncode(oldValues) : null),
            newValues: Value(newValues != null ? jsonEncode(newValues) : null),
            userId: Value(userId),
          ),
        );
  }

  /// الحصول على سجل التدقيقات لكيان معين
  Future<List<AccAuditLog>> getAuditLogForTable(
      String logTableName, String recordId) async {
    return (db.select(db.accAuditLogs)
          ..where((t) =>
              t.logTableName.equals(logTableName) & t.recordId.equals(recordId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
  }

  /// الحصول على سجل التدقيقات لمستخدم معين
  Future<List<AccAuditLog>> getAuditLogForUser(String userId) async {
    return (db.select(db.accAuditLogs)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
  }
}
