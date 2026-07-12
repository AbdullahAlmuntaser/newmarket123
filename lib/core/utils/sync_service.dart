import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart';

enum SyncDirection { push, pull, both }

enum ConflictStrategy { serverWins, clientWins, lastWriteWins, manual }

class SyncService {
  final AppDatabase db;
  Timer? _syncTimer;
  bool _isSyncing = false;
  SyncDirection _direction = SyncDirection.both;
  ConflictStrategy _conflictStrategy = ConflictStrategy.lastWriteWins;

  bool get isSyncing => _isSyncing;
  SyncDirection get direction => _direction;
  ConflictStrategy get conflictStrategy => _conflictStrategy;

  SyncService(this.db);

  void setDirection(SyncDirection dir) => _direction = dir;
  void setConflictStrategy(ConflictStrategy strategy) =>
      _conflictStrategy = strategy;

  void startAutoSync({Duration interval = const Duration(minutes: 5)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => syncWithCloud());
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> addToQueue({
    required String table,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final encodedPayload = jsonEncode(payload);
    await db.transaction(() async {
      final existing = await (db.select(db.syncQueue)
            ..where((q) => q.entityTable.equals(table))
            ..where((q) => q.entityId.equals(entityId))
            ..where((q) => q.operation.equals(operation))
            ..where((q) => q.status.equals(0) | q.status.equals(-1)))
          .getSingleOrNull();

      if (existing != null) {
        await (db.update(db.syncQueue)..where((q) => q.id.equals(existing.id)))
            .write(
          SyncQueueCompanion(
            payload: Value(encodedPayload),
            status: const Value(0),
            lastError: const Value(null),
          ),
        );
        return;
      }

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              entityTable: table,
              entityId: entityId,
              operation: operation,
              payload: encodedPayload,
              status: const Value(0),
              version: const Value(1),
              retryCount: const Value(0),
            ),
          );
    });
  }

  Future<List<SyncQueueData>> getPendingItems({int limit = 100}) {
    return (db.select(db.syncQueue)
          ..where((t) => t.status.equals(0) | t.status.equals(-1))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<int> getPendingCount() async {
    final result = await db
        .customSelect(
          "SELECT COUNT(*) as cnt FROM sync_queue WHERE status = 0 OR status = -1",
        )
        .getSingle();
    return result.data['cnt'] as int;
  }

  Future<int> getFailedCount() async {
    final result = await db
        .customSelect(
          "SELECT COUNT(*) as cnt FROM sync_queue WHERE status = -1",
        )
        .getSingle();
    return result.data['cnt'] as int;
  }

  Future<void> markAsSynced(String queueId) async {
    await (db.update(db.syncQueue)..where((t) => t.id.equals(queueId))).write(
      const SyncQueueCompanion(
        status: Value(1),
        retryCount: Value(0),
        lastError: Value(null),
      ),
    );
  }

  Future<void> markAsFailed(String queueId, String error) async {
    final item = await (db.select(db.syncQueue)
          ..where((t) => t.id.equals(queueId)))
        .getSingle();
    final newRetryCount = item.retryCount + 1;
    final newStatus = newRetryCount >= 5 ? -2 : -1;

    await (db.update(db.syncQueue)..where((t) => t.id.equals(queueId))).write(
      SyncQueueCompanion(
        status: Value(newStatus),
        retryCount: Value(newRetryCount),
        lastError: Value(error),
      ),
    );
  }

  Future<void> retryFailed() async {
    final failed = await (db.select(db.syncQueue)
          ..where((t) => t.status.equals(-1)))
        .get();

    for (final item in failed) {
      await (db.update(db.syncQueue)..where((t) => t.id.equals(item.id))).write(
        const SyncQueueCompanion(status: Value(0)),
      );
    }
  }

  Future<void> clearSynced() async {
    await (db.delete(db.syncQueue)..where((t) => t.status.equals(1))).go();
  }

  Future<Map<String, dynamic>> syncWithCloud() async {
    if (_isSyncing) return {'status': 'already_syncing'};

    _isSyncing = true;
    final results = <String, dynamic>{
      'pushed': 0,
      'failed': 0,
      'conflicts': 0,
      'pulled': 0,
    };

    try {
      if (_direction == SyncDirection.push ||
          _direction == SyncDirection.both) {
        final pending = await getPendingItems();
        for (final item in pending) {
          if (item.retryCount > 0) {
            final waitTime = pow(2, min(item.retryCount, 6)) * 5;
            if (item.createdAt
                .add(Duration(seconds: waitTime.toInt()))
                .isAfter(DateTime.now())) {
              continue;
            }
          }

          try {
            await _pushToServer(item);
            await markAsSynced(item.id);
            results['pushed'] = (results['pushed'] as int) + 1;
          } catch (e) {
            final isConflict = e.toString().contains('CONFLICT');
            if (isConflict) {
              await _resolveConflict(item, e.toString());
              results['conflicts'] = (results['conflicts'] as int) + 1;
            } else {
              await markAsFailed(item.id, e.toString());
              results['failed'] = (results['failed'] as int) + 1;
            }
          }
        }
      }

      if (_direction == SyncDirection.pull ||
          _direction == SyncDirection.both) {
        final pulledCount = await _pullFromServer();
        results['pulled'] = pulledCount;
      }
    } finally {
      _isSyncing = false;
    }

    return results;
  }

  Future<void> _pushToServer(SyncQueueData item) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<int> _pullFromServer() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return 0;
  }

  Future<void> _resolveConflict(SyncQueueData item, String error) async {
    switch (_conflictStrategy) {
      case ConflictStrategy.serverWins:
        await markAsSynced(item.id);
        break;
      case ConflictStrategy.clientWins:
        await markAsSynced(item.id);
        break;
      case ConflictStrategy.lastWriteWins:
        await markAsSynced(item.id);
        break;
      case ConflictStrategy.manual:
        await markAsFailed(item.id, 'CONFLICT: $error');
        break;
    }
  }

  Future<List<Map<String, dynamic>>> getSyncHistory({int limit = 50}) async {
    final items = await (db.select(db.syncQueue)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();

    return items
        .map((item) => {
              'id': item.id,
              'table': item.entityTable,
              'entityId': item.entityId,
              'operation': item.operation,
              'status': item.status,
              'retryCount': item.retryCount,
              'error': item.lastError,
              'createdAt': item.createdAt.toIso8601String(),
            })
        .toList();
  }

  Future<Map<String, int>> getSyncStats() async {
    final pending = await getPendingCount();
    final failed = await getFailedCount();

    final syncedResult = await db
        .customSelect(
          "SELECT COUNT(*) as cnt FROM sync_queue WHERE status = 1",
        )
        .getSingle();

    return {
      'pending': pending,
      'failed': failed,
      'synced': syncedResult.data['cnt'] as int,
    };
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}
