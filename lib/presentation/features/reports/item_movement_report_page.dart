import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/shared/period_filter_widget.dart';
import 'package:supermarket/presentation/widgets/entity_picker.dart';
import 'package:intl/intl.dart' as intl;

class ItemMovementReportPage extends StatefulWidget {
  const ItemMovementReportPage({super.key});

  @override
  State<ItemMovementReportPage> createState() => _ItemMovementReportPageState();
}

class _ItemMovementReportPageState extends State<ItemMovementReportPage> {
  Product? _selectedProduct;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<StockMovement>? _movements;
  bool _isLoading = false;

  Future<void> _loadReport() async {
    if (_selectedProduct == null) return;
    setState(() => _isLoading = true);
    final db = Provider.of<AppDatabase>(context, listen: false);
    final result = await db.stockMovementDao.getProductMovementReport(
      productId: _selectedProduct!.id,
      startDate: _startDate,
      endDate: _endDate,
    );
    setState(() {
      _movements = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('تقرير حركة الصنف')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ProductPicker(
                  db: db,
                  value: _selectedProduct,
                  onChanged: (p) {
                    setState(() => _selectedProduct = p);
                    _loadReport();
                  },
                ),
                const SizedBox(height: 10),
                PeriodFilterWidget(
                  onFilter: (start, end) {
                    setState(() {
                      _startDate = start;
                      _endDate = end;
                    });
                    _loadReport();
                  },
                ),
              ],
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_movements != null)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('التاريخ')),
                      DataColumn(label: Text('النوع')),
                      DataColumn(label: Text('الكمية')),
                      DataColumn(label: Text('التكلفة')),
                      DataColumn(label: Text('المرجع')),
                    ],
                    rows: _movements!.map((m) {
                      return DataRow(cells: [
                        DataCell(Text(intl.DateFormat('yyyy-MM-dd HH:mm').format(m.movementDate))),
                        DataCell(Text(m.type)),
                        DataCell(Text(m.quantity.toString(), style: TextStyle(color: m.quantity > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold))),
                        DataCell(Text(m.cost.toStringAsFixed(2))),
                        DataCell(Text(m.referenceId ?? '')),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
