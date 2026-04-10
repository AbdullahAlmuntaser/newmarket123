import 'package:flutter/foundation.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class SyncService {
  final AppDatabase db;
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  SyncService(this.db);

  Future<void> syncAll() async {
    // Cloud sync is disabled as Firebase is removed.
    // Keeping the method signature to avoid breaking UI components.
    lastError.value = "المزامنة السحابية غير مفعلة (تم إزالة Firebase)";
    return;
  }

  Future<void> pushChanges() async {
    // Disabled
  }

  Future<void> pullChanges() async {
    // Disabled
  }
}
