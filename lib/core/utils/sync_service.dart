import 'dart:convert';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart';

class SyncService {
  final AppDatabase db;
  
  SyncService(this.db);

  /// Adds an operation to the sync queue
  Future<void> addToQueue({
    required String table,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await db.into(db.syncQueue).insert(
      SyncQueueCompanion.insert(
        entityTable: table,
        entityId: entityId,
        operation: operation,
        payload: jsonEncode(payload),
        status: const Value(0), // 0: Pending, 1: Synced, -1: Failed
      ),
    );
  }

  /// Gets pending items from the queue
  Future<List<SyncQueueData>> getPendingItems() {
    return (db.select(db.syncQueue)..where((t) => t.status.equals(0))).get();
  }

  /// Mark an item as synced
  Future<void> markAsSynced(int queueId) async {
    await (db.update(db.syncQueue)..where((t) => t.id.equals(queueId))).write(
      const SyncQueueCompanion(status: Value(1)),
    );
  }

  /// This is where the actual HTTP sync logic would go
  Future<void> syncWithCloud() async {
    final pending = await getPendingItems();
    for (var item in pending) {
      try {
        // Pseudo-code for Cloud API call:
        // await cloudApi.sync(item.entityTable, item.operation, item.payload);
        
        await markAsSynced(item.id);
      } catch (e) {
        // Log sync error using developer.log or a dedicated logger
      }
    }
  }
}
