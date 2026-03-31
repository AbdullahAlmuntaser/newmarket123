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
    await db
        .into(db.auditLogs)
        .insert(
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

  // Helper methods for common actions
  Future<void> logCreate(
    String entity,
    String id, {
    String? details,
    String? userId,
  }) => log(
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
  }) => log(
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
  }) => log(
    action: 'DELETE',
    targetEntity: entity,
    entityId: id,
    details: details,
    userId: userId,
  );
}
