import 'package:flutter/material.dart';
import 'package:supermarket/core/services/supplier_analytics_service.dart';
import 'package:supermarket/injection_container.dart';

class SupplierPerformancePage extends StatefulWidget {
  const SupplierPerformancePage({super.key});

  @override
  State<SupplierPerformancePage> createState() =>
      _SupplierPerformancePageState();
}

class _SupplierPerformancePageState extends State<SupplierPerformancePage> {
  final SupplierAnalyticsService _service = sl<SupplierAnalyticsService>();
  List<SupplierPerformance> _report = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    _report = await _service.getSupplierPerformanceReport();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير أداء الموردين')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _report.length,
              itemBuilder: (context, index) {
                final p = _report[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: ListTile(
                    title: Text(p.supplierName),
                    subtitle: Text('عدد الفواتير: ${p.totalInvoices}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'الإجمالي: ${p.totalPurchases.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'متوسط الفاتورة: ${p.averagePrice.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
