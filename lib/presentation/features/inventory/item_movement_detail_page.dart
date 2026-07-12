import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart' as di;
import 'package:intl/intl.dart';

class ItemMovementDetailPage extends StatefulWidget {
  final String productId;
  final String productName;

  const ItemMovementDetailPage({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<ItemMovementDetailPage> createState() => _ItemMovementDetailPageState();
}

class _ItemMovementDetailPageState extends State<ItemMovementDetailPage> {
  List<StockMovement> _movements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = di.sl<AppDatabase>();
    _movements = await (db.select(db.stockMovements)
          ..where((m) => m.productId.equals(widget.productId))
          ..orderBy([(m) => OrderingTerm.desc(m.movementDate)]))
        .get();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('حركة صنف: ${widget.productName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _movements.isEmpty
              ? const Center(child: Text('لا توجد حركات لهذا الصنف'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _movements.length,
                  itemBuilder: (context, index) {
                    final m = _movements[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _getTypeColor(m.type).withOpacity(0.1),
                          child: Icon(_getTypeIcon(m.type),
                              color: _getTypeColor(m.type), size: 20),
                        ),
                        title: Text(_getTypeText(m.type)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(m.movementDate)}'),
                            if (m.referenceId != null)
                              Text(
                                  'المرجع: ${m.referenceId!.substring(0, 8)}...'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${m.quantity > Decimal.zero ? '+' : ''}${m.quantity}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: m.quantity > Decimal.zero
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            if (m.cost > Decimal.zero)
                              Text('${m.cost} ر.س',
                                  style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'purchase':
        return Colors.green;
      case 'sale':
        return Colors.red;
      case 'adjustment':
        return Colors.orange;
      case 'transferIn':
        return Colors.blue;
      case 'transferOut':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'purchase':
        return Icons.add_shopping_cart;
      case 'sale':
        return Icons.shopping_cart;
      case 'adjustment':
        return Icons.tune;
      case 'transferIn':
        return Icons.arrow_downward;
      case 'transferOut':
        return Icons.arrow_upward;
      default:
        return Icons.inventory;
    }
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'purchase':
        return 'شراء';
      case 'sale':
        return 'بيع';
      case 'adjustment':
        return 'تعديل مخزون';
      case 'transferIn':
        return 'تحويل وارد';
      case 'transferOut':
        return 'تحويل صادر';
      default:
        return type;
    }
  }
}
