import 'dart:convert';
import 'dart:math';
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
            status: const Value(0),
            version: const Value(1),
            retryCount: const Value(0),
          ),
        );
  }

  /// Gets pending items from the queue
  Future<List<SyncQueueData>> getPendingItems() {
    return (db.select(db.syncQueue)..where((t) => t.status.equals(0) | t.status.equals(-1))).get();
  }

  /// Mark an item as synced
  Future<void> markAsSynced(String queueId) async {
    await (db.update(db.syncQueue)..where((t) => t.id.equals(queueId))).write(
      const SyncQueueCompanion(status: Value(1), retryCount: Value(0), lastError: Value(null)),
    );
  }

  /// Mark an item as failed
  Future<void> markAsFailed(String queueId, String error) async {
    final item = await (db.select(db.syncQueue)..where((t) => t.id.equals(queueId))).getSingle();
    await (db.update(db.syncQueue)..where((t) => t.id.equals(queueId))).write(
      SyncQueueCompanion(
        status: const Value(-1),
        retryCount: Value(item.retryCount + 1),
        lastError: Value(error),
      ),
    );
  }

  Future<void> syncWithCloud() async {
    final pending = await getPendingItems();
    for (var item in pending) {
      // Exponential Backoff Logic: Wait 2^retryCount * 5 seconds
      if (item.retryCount > 0) {
        final waitTime = pow(2, min(item.retryCount, 6)) * 5;
        if (item.createdAt.add(Duration(seconds: waitTime.toInt())).isAfter(DateTime.now())) {
          continue;
        }
      }

      try {
        // Here, the actual API call logic would interface with the cloud
        // Example: await cloudApi.sync(item.entityTable, item.operation, jsonDecode(item.payload));
        
        await markAsSynced(item.id);
      } catch (e) {
        await markAsFailed(item.id, e.toString());
      }
    }
  }
}
