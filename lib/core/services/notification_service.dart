import 'package:uuid/uuid.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}

class NotificationService {
  final List<AppNotification> _notifications = [];

  Stream<List<AppNotification>> get notificationsStream async* {
    yield _notifications;
  }

  void notify({required String title, required String message}) {
    final n = AppNotification(
      id: const Uuid().v4(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
    );
    _notifications.insert(0, n);
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final n = _notifications[index];
      _notifications[index] = AppNotification(
        id: n.id,
        title: n.title,
        message: n.message,
        timestamp: n.timestamp,
        isRead: true,
      );
    }
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
}
