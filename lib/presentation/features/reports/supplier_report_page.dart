import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart' as di;
import 'package:supermarket/core/utils/export_service.dart';

class SupplierReportPage extends StatefulWidget {
  const SupplierReportPage({super.key});

  @override
  State<SupplierReportPage> createState() => _SupplierReportPageState();
}

class _SupplierReportPageState extends State<SupplierReportPage> {
  List<Supplier> _suppliers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = di.sl<AppDatabase>();
    _suppliers = await (db.select(db.suppliers)
          ..where((s) => s.isActive.equals(true)))
        .get();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _suppliers
        .where((s) =>
            s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (s.phone?.contains(_searchQuery) ?? false))
        .toList();

    final totalBalance =
        filtered.fold<double>(0, (sum, s) => sum + s.balance.toDouble());

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير الموردين'),
        actions: [
          IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _exportToPdf(filtered)),
          IconButton(
              icon: const Icon(Icons.table_chart),
              onPressed: () => _exportToExcel(filtered)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث بالاسم أو الهاتف...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('إجمالي الموردين', '${filtered.length}'),
                _statItem('الرصيد الإجمالي',
                    '${totalBalance.toStringAsFixed(2)} ر.س'),
                _statItem('موردين بدين',
                    '${filtered.where((s) => s.balance > Decimal.zero).length}'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final supplier = filtered[index];
                      return ListTile(
                        title: Text(supplier.name),
                        subtitle: Text(supplier.phone ?? ''),
                        trailing: Text(
                          '${supplier.balance} ر.س',
                          style: TextStyle(
                            color: supplier.balance > Decimal.zero
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _exportToPdf(List<Supplier> data) async {
    final service = ExportService(di.sl<AppDatabase>());
    await service.exportToPdf(
        'suppliers',
        data
            .map((s) => {
                  'name': s.name,
                  'phone': s.phone ?? '',
                  'balance': s.balance.toString(),
                })
            .toList());
  }

  void _exportToExcel(List<Supplier> data) async {
    final service = ExportService(di.sl<AppDatabase>());
    await service.exportToCsv(
        'suppliers',
        data
            .map((s) => {
                  'name': s.name,
                  'phone': s.phone ?? '',
                  'balance': s.balance.toString(),
                })
            .toList());
  }
}
