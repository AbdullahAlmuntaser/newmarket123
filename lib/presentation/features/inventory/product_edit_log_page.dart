import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart' as di;
import 'package:intl/intl.dart';

class ProductEditLogPage extends StatefulWidget {
  const ProductEditLogPage({super.key});

  @override
  State<ProductEditLogPage> createState() => _ProductEditLogPageState();
}

class _ProductEditLogPageState extends State<ProductEditLogPage> {
  List<AuditLog> _logs = [];
  bool _isLoading = true;
  String? _selectedEntityType;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = di.sl<AppDatabase>();
    var query = db.select(db.auditLogs)
      ..orderBy([(l) => OrderingTerm.desc(l.timestamp)]);
    if (_selectedEntityType != null) {
      query = query..where((l) => l.targetEntity.equals(_selectedEntityType!));
    }
    _logs = await query.get();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التعديلات'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: DropdownButtonFormField<String>(
              value: _selectedEntityType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'نوع السجل',
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('الكل')),
                DropdownMenuItem(value: 'PRODUCT', child: Text('منتجات')),
                DropdownMenuItem(
                    value: 'SALES_INVOICE', child: Text('فواتير مبيعات')),
                DropdownMenuItem(
                    value: 'PURCHASE', child: Text('فواتير مشتريات')),
                DropdownMenuItem(
                    value: 'SALES_ORDER', child: Text('طلبيات مبيعات')),
                DropdownMenuItem(value: 'CUSTOMER', child: Text('عملاء')),
                DropdownMenuItem(value: 'SUPPLIER', child: Text('موردين')),
                DropdownMenuItem(value: 'INVENTORY', child: Text('مخزون')),
              ],
              onChanged: (val) => setState(() {
                _selectedEntityType = val;
                _loadData();
              }),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const Center(child: Text('لا توجد سجلات'))
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getActionColor(log.action)
                                    .withOpacity(0.1),
                                child: Icon(_getActionIcon(log.action),
                                    color: _getActionColor(log.action),
                                    size: 18),
                              ),
                              title: Text(
                                  '${_getActionText(log.action)} - ${log.targetEntity}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (log.details != null)
                                    Text(log.details!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12)),
                                  Text(
                                    DateFormat('yyyy-MM-dd HH:mm')
                                        .format(log.timestamp),
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'CREATE':
        return Colors.green;
      case 'UPDATE':
        return Colors.orange;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'CREATE':
        return Icons.add_circle;
      case 'UPDATE':
        return Icons.edit;
      case 'DELETE':
        return Icons.delete;
      default:
        return Icons.info;
    }
  }

  String _getActionText(String action) {
    switch (action) {
      case 'CREATE':
        return 'إنشاء';
      case 'UPDATE':
        return 'تعديل';
      case 'DELETE':
        return 'حذف';
      default:
        return action;
    }
  }
}
