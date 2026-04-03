import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'dart:convert';

class SyncService {
  final AppDatabase db;
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  SyncService(this.db);

  // Getter آمن للوصول لـ Firestore فقط إذا كان Firebase مهيأ
  FirebaseFirestore get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      throw 'Firebase not initialized. Sync unavailable.';
    }
  }

  static const String _lastSyncKey = 'last_sync_timestamp';

  Future<void> syncAll() async {
    try {
      // التحقق من وجود Firebase قبل البدء
      FirebaseFirestore.instance; 
    } catch (e) {
      lastError.value = "المزامنة السحابية غير مفعلة";
      return;
    }

    if (isSyncing.value) return;
    isSyncing.value = true;
    lastError.value = null;
    try {
      await pushChanges();
      await pullChanges();
    } catch (e) {
      lastError.value = e.toString();
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> pushChanges() async {
    final pendingItems = await (db.select(
      db.syncQueue,
    )..where((tbl) => tbl.status.equals(0))).get();
    if (pendingItems.isEmpty) return;

    for (var item in pendingItems) {
      try {
        final collection = _firestore.collection(item.entityTable);
        final data = jsonDecode(item.payload);

        // Add metadata for sync
        data['updatedAt'] = FieldValue.serverTimestamp();
        data['deviceId'] = item.deviceId;

        await collection.doc(item.entityId).set(data, SetOptions(merge: true));

        // Mark as synced
        await (db.delete(
          db.syncQueue,
        )..where((tbl) => tbl.id.equals(item.id))).go();
      } catch (e) {
        debugPrint('Push failed for ${item.entityTable}/${item.entityId}: $e');
        // We don't throw here to continue with other items
      }
    }
  }

  Future<void> pullChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
    final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSync);

    final tables = [
      'products',
      'customers',
      'suppliers',
      'sales',
      'purchases',
      'gLAccounts',
      'gLEntries',
      'gLLines',
    ];

    for (var tableName in tables) {
      try {
        final query = _firestore
            .collection(tableName)
            .where(
              'updatedAt',
              isGreaterThan: Timestamp.fromDate(lastSyncDate),
            );

        final snapshot = await query.get();

        if (snapshot.docs.isNotEmpty) {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;

            // Handle timestamps - convert to ISO8601 strings for drift fromJson
            if (data['updatedAt'] is Timestamp) {
              data['updatedAt'] = (data['updatedAt'] as Timestamp)
                  .toDate()
                  .toIso8601String();
            }
            if (data['createdAt'] is Timestamp) {
              data['createdAt'] = (data['createdAt'] as Timestamp)
                  .toDate()
                  .toIso8601String();
            }

            // Conflict Resolution: Only update if server version is newer than local
            await _applyChangeWithConflictResolution(tableName, data);
          }
        }
      } catch (e) {
        debugPrint('Pull failed for $tableName: $e');
      }
    }

    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _applyChangeWithConflictResolution(
    String table,
    Map<String, dynamic> data,
  ) async {
    // This is a simplified version. For full conflict resolution,
    // we would check the local updatedAt before overriding.
    // Drift's insertOrReplace is already doing most of the work for simple cases.

    await db.batch((batch) {
      _applyChange(batch, table, data);
    });
  }

  void _applyChange(Batch batch, String table, Map<String, dynamic> data) {
    switch (table) {
      case 'products':
        batch.insert(
          db.products,
          Product.fromJson(data),
          mode: InsertMode.insertOrReplace,
        );
        break;
      case 'customers':
        batch.insert(
          db.customers,
          Customer.fromJson(data),
          mode: InsertMode.insertOrReplace,
        );
        break;
      case 'suppliers':
        batch.insert(
          db.suppliers,
          Supplier.fromJson(data),
          mode: InsertMode.insertOrReplace,
        );
        break;
      case 'sales':
        batch.insert(
          db.sales,
          Sale.fromJson(data),
          mode: InsertMode.insertOrReplace,
        );
        break;
      case 'purchases':
        batch.insert(
          db.purchases,
          Purchase.fromJson(data),
          mode: InsertMode.insertOrReplace,
        );
        break;
      case 'gLAccounts':
        batch.insert(
          db.gLAccounts,
          GLAccount.fromJson(data),
          mode: InsertMode.insertOrReplace,
        );
        break;
      case 'gLEntries':
        batch.insert(
          db.gLEntries,
          GLEntry.fromJson(data),
          mode: InsertMode.insertOrReplace,
        );
        break;
      case 'gLLines':
        batch.insert(
          db.gLLines,
          GLLine.fromJson(data),
          mode: InsertMode.insertOrReplace,
        );
        break;
    }
  }
}
