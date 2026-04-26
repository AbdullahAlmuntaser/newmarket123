import 'package:flutter/material.dart';
import 'package:supermarket/core/services/profitability_service.dart';
import 'package:supermarket/injection_container.dart';

class ProfitabilityReportPage extends StatefulWidget {
  const ProfitabilityReportPage({super.key});

  @override
  State<ProfitabilityReportPage> createState() =>
      _ProfitabilityReportPageState();
}

class _ProfitabilityReportPageState extends State<ProfitabilityReportPage> {
  final ProfitabilityService _service = ProfitabilityService(sl());
  ProfitabilityReport? _report;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    _report = await _service.getGrossProfitReport(start, now);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير الأرباح الشهرية')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
          ? const Center(child: Text('لا توجد بيانات'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildCard('إجمالي المبيعات', _report!.totalRevenue),
                  _buildCard('إجمالي تكلفة البضاعة', _report!.totalCost),
                  _buildCard(
                    'إجمالي الربح',
                    _report!.grossProfit,
                    color: Colors.green,
                  ),
                  _buildCard(
                    'هامش الربح',
                    _report!.profitMargin,
                    isPercent: true,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard(
    String title,
    double value, {
    Color? color,
    bool isPercent = false,
  }) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          isPercent ? '${value.toStringAsFixed(2)}%' : value.toStringAsFixed(2),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
      ),
    );
  }
}
