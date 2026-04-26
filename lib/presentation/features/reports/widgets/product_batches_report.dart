import 'package:flutter/material.dart';
import 'package:supermarket/core/services/inventory_service.dart';
import 'package:supermarket/injection_container.dart';
import 'package:intl/intl.dart';

class ProductBatchesReportWidget extends StatelessWidget {
  const ProductBatchesReportWidget({super.key});

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
              'دفعات المنتجات المتوفرة',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<BatchReport>>(
              stream: inventoryService.watchProductBatches(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final batches = snapshot.data ?? [];

                if (batches.isEmpty) {
                  return const Center(child: Text('لا توجد دفعات حالياً'));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('رقم الدفعة')),
                      DataColumn(label: Text('المنتج')),
                      DataColumn(label: Text('تاريخ الصلاحية')),
                      DataColumn(label: Text('الكمية المتبقية'), numeric: true),
                      DataColumn(label: Text('سعر التكلفة'), numeric: true),
                      DataColumn(label: Text('المستودع')),
                    ],
                    rows: batches.where((b) => b.batch.quantity > 0).map((b) {
                      return DataRow(
                        cells: [
                          DataCell(Text(b.batch.id.substring(0, 8))),
                          DataCell(Text(b.product.name)),
                          DataCell(
                            Text(
                              b.batch.expiryDate != null
                                  ? DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(b.batch.expiryDate!)
                                  : '-',
                            ),
                          ),
                          DataCell(Text(b.batch.quantity.toString())),
                          DataCell(Text(b.batch.costPrice.toStringAsFixed(2))),
                          DataCell(Text(b.warehouse?.name ?? 'افتراضي')),
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
