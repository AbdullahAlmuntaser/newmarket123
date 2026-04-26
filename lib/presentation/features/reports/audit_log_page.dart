import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: const Text('سجل التدقيق والرقابة')),
      body: StreamBuilder<List<AuditLog>>(
        stream: (db.select(
          db.auditLogs,
        )..orderBy([(t) => drift.OrderingTerm.desc(t.timestamp)])).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = snapshot.data!;
          if (logs.isEmpty) {
            return const Center(child: Text('لا يوجد سجلات تدقيق بعد.'));
          }

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: _buildActionIcon(log.action),
                  title: Text('${log.targetEntity}: ${log.action}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log.details ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: Text('المستخدم: ${log.userId ?? "نظام"}'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return const Icon(Icons.add_circle, color: Colors.green);
      case 'UPDATE':
        return const Icon(Icons.edit, color: Colors.blue);
      case 'DELETE':
        return const Icon(Icons.delete_forever, color: Colors.red);
      default:
        return const Icon(Icons.info, color: Colors.grey);
    }
  }
}
