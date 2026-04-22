import 'package:flutter/material.dart';
import 'package:supermarket/core/services/inventory_service.dart';
import 'package:supermarket/injection_container.dart';
import 'package:intl/intl.dart';

class InventoryTransactionsReportWidget extends StatelessWidget {
  const InventoryTransactionsReportWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final inventoryService = sl<InventoryService>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'حركات المخزون الأخيرة',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<InventoryTransactionReport>>(
              stream: inventoryService.watchInventoryTransactions(limit: 10),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final transactions = snapshot.data ?? [];

                if (transactions.isEmpty) {
                  return const Center(child: Text('لا توجد حركات مخزون'));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('التاريخ')),
                      DataColumn(label: Text('المنتج')),
                      DataColumn(label: Text('النوع')),
                      DataColumn(label: Text('الكمية'), numeric: true),
                      DataColumn(label: Text('المستودع')),
                    ],
                    rows: transactions.map((t) {
                      return DataRow(
                        cells: [
                          DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(t.transaction.date))),
                          DataCell(Text(t.product.name)),
                          DataCell(Text(t.transaction.type)),
                          DataCell(Text(t.transaction.quantity.toString())),
                          DataCell(Text(t.warehouse?.name ?? 'افتراضي')),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
