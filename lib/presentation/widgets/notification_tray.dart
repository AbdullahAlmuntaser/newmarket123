import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/services/notification_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:intl/intl.dart' as intl;

class NotificationTray extends StatefulWidget {
  const NotificationTray({super.key});

  @override
  State<NotificationTray> createState() => _NotificationTrayState();
}

class _NotificationTrayState extends State<NotificationTray> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAlerts());
  }

  Future<void> _refreshAlerts() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await context.read<NotificationService>().refreshOperationalAlerts(
            context.read<AppDatabase>(),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحديث الإشعارات: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  IconData _iconFor(AppNotification notification) {
    if (notification.isRead) return Icons.notifications_none;
    if (notification.severity == 'critical') return Icons.error_outline;
    if (notification.severity == 'warning') return Icons.warning_amber;
    return Icons.notifications_active;
  }

  Color _colorFor(AppNotification notification) {
    if (notification.isRead) return Colors.grey;
    if (notification.severity == 'critical') return Colors.red;
    if (notification.severity == 'warning') return Colors.orange;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = context.watch<NotificationService>();

    return Drawer(
      child: Column(
        children: [
          AppBar(
            title: const Text('الإشعارات'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                tooltip: 'تحديث التنبيهات',
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: _isRefreshing ? null : _refreshAlerts,
              ),
              IconButton(
                tooltip: 'تحديد الكل كمقروء',
                icon: const Icon(Icons.done_all),
                onPressed: notificationService.unreadCount == 0
                    ? null
                    : notificationService.markAllAsRead,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: notificationService.notificationsStream,
              initialData: notificationService.notifications,
              builder: (context, snapshot) {
                final notifications = snapshot.data ?? const [];
                if (notifications.isEmpty) {
                  return const Center(child: Text('لا توجد إشعارات جديدة'));
                }
                return RefreshIndicator(
                  onRefresh: _refreshAlerts,
                  child: ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      return ListTile(
                        leading: Icon(_iconFor(n), color: _colorFor(n)),
                        title: Text(
                          n.title,
                          style: TextStyle(
                            fontWeight:
                                n.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${n.message}\n${intl.DateFormat('yyyy-MM-dd HH:mm').format(n.timestamp)}',
                        ),
                        isThreeLine: true,
                        onTap: () => notificationService.markAsRead(n.id),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
