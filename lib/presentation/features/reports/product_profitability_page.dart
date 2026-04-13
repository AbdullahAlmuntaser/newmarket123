import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/sales_dao.dart';
import 'package:intl/intl.dart';

class ProductProfitabilityPage extends StatefulWidget {
  const ProductProfitabilityPage({super.key});

  @override
  State<ProductProfitabilityPage> createState() => _ProductProfitabilityPageState();
}

class _ProductProfitabilityPageState extends State<ProductProfitabilityPage> {
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final currencyFormat = NumberFormat.currency(symbol: '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير ربحية المنتجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: _selectedRange,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedRange = picked);
            },
          ),
        ],
      ),
      body: FutureBuilder<List<ProductProfitability>>(
        future: db.salesDao.getProductProfitability(
          startDate: _selectedRange.start,
          endDate: _selectedRange.end,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text('لا توجد مبيعات في هذه الفترة.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.productName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item.profitMargin.toStringAsFixed(1)}%',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn('الكمية', item.totalQuantity.toStringAsFixed(0)),
                          _buildStatColumn('الإيرادات', currencyFormat.format(item.totalRevenue)),
                          _buildStatColumn('التكلفة', currencyFormat.format(item.totalCost)),
                          _buildStatColumn('الربح', currencyFormat.format(item.netProfit), isHighlight: true),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isHighlight ? Colors.green : null,
          ),
        ),
      ],
    );
  }
}
