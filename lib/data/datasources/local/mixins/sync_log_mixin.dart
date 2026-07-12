import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'dart:convert';

mixin SyncLogMixin on DatabaseAccessor<AppDatabase> {
  Future<void> logSyncOperation({
    required String table,
    required String entityId,
    required String operation,
    Map<String, dynamic>? payload,
  }) async {
    await into(db.syncQueue).insert(
      SyncQueueCompanion.insert(
        entityTable: table,
        entityId: entityId,
        operation: operation,
        payload: payload != null ? jsonEncode(payload) : '{}',
        createdAt: Value(DateTime.now()),
        status: const Value(0),
      ),
    );
  }
}
