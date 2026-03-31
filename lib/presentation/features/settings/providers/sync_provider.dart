import 'package:flutter/material.dart';

class SyncProvider with ChangeNotifier {
  bool get isSyncing => false;
  DateTime? get lastSyncTime => null;

  Future<void> syncAll() async {
    // Implementation for syncing all changes
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }
}
