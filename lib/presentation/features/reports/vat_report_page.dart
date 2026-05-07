import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/event_bus_service.dart';

class VatReportPage extends StatefulWidget {
  const VatReportPage({super.key});

  @override
  State<VatReportPage> createState() => _VatReportPageState();
}

class _VatReportPageState extends State<VatReportPage> {
  final DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('تقرير ضريبة القيمة المضافة')),
      drawer: const MainDrawer(),
      body: FutureBuilder<VatReportData>(
        future: _fetchVatReport(db),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle('المبيعات والمخرجات'),
              _buildCard('إجمالي المبيعات الخاضعة للضريبة', data.totalTaxableSales),
              _buildCard('إجمالي ضريبة المخرجات', data.totalOutputVat),
              const SizedBox(height: 16),
              
              _buildSectionTitle('المشتريات والمدخلات'),
              _buildCard('إجمالي المشتريات الخاضعة للضريبة', data.totalTaxablePurchases),
              _buildCard('إجمالي ضريبة المدخلات', data.totalInputVat),
              const SizedBox(height: 16),
              
              const Divider(thickness: 2),
              _buildCard('صافي الضريبة المستحقة (للدفع/للاسترداد)', data.netVatPayable, isHighlight: true),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }

  Future<VatReportData> _fetchVatReport(AppDatabase db) async {
    final service = AccountingService(db, Provider.of<EventBusService>(context, listen: false));
    return await service.getVatReport(
      startDate: _range.start,
      endDate: _range.end,
    );
  }

  Widget _buildCard(String title, double amount, {bool isHighlight = false}) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          NumberFormat.currency(symbol: '').format(amount),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isHighlight ? (amount >= 0 ? Colors.red : Colors.green) : null,
          ),
        ),
      ),
    );
  }
}
