import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class AuditService {
  final AppDatabase db;

  AuditService(this.db);

  Future<void> log({
    String? userId,
    required String action,
    required String targetEntity,
    required String entityId,
    String? details,
  }) async {
    await db.into(db.auditLogs).insert(
          AuditLogsCompanion.insert(
            userId: Value(userId),
            action: action,
            targetEntity: targetEntity,
            entityId: entityId,
            details: Value(details),
            timestamp: Value(DateTime.now()),
          ),
        );
  }

  Future<void> logCreate(
    String entity,
    String id, {
    String? details,
    String? userId,
  }) =>
      log(
        action: 'CREATE',
        targetEntity: entity,
        entityId: id,
        details: details,
        userId: userId,
      );

  Future<void> logUpdate(
    String entity,
    String id, {
    String? details,
    String? userId,
  }) =>
      log(
        action: 'UPDATE',
        targetEntity: entity,
        entityId: id,
        details: details,
        userId: userId,
      );

  Future<void> logDelete(
    String entity,
    String id, {
    String? details,
    String? userId,
  }) =>
      log(
        action: 'DELETE',
        targetEntity: entity,
        entityId: id,
        details: details,
        userId: userId,
      );

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

  Future<List<AccAuditLog>> getAuditLogForTable(
      String logTableName, String recordId) async {
    return (db.select(db.accAuditLogs)
          ..where((t) =>
              t.logTableName.equals(logTableName) & t.recordId.equals(recordId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
  }

  Future<List<AccAuditLog>> getAuditLogForUser(String userId) async {
    return (db.select(db.accAuditLogs)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
  }
}
