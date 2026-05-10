import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/services/notification_service.dart';
import 'package:intl/intl.dart' as intl;

class NotificationTray extends StatelessWidget {
  const NotificationTray({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationService = Provider.of<NotificationService>(context);

    return Drawer(
      child: Column(
        children: [
          AppBar(
            title: const Text('الإشعارات'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: notificationService.notificationsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('لا توجد إشعارات جديدة'));
                }
                final notifications = snapshot.data!;
                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    return ListTile(
                      leading: Icon(
                        n.isRead ? Icons.notifications_none : Icons.notifications_active,
                        color: n.isRead ? Colors.grey : Colors.blue,
                      ),
                      title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                      subtitle: Text('${n.message}\n${intl.DateFormat('yyyy-MM-dd HH:mm').format(n.timestamp)}'),
                      isThreeLine: true,
                      onTap: () => notificationService.markAsRead(n.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
