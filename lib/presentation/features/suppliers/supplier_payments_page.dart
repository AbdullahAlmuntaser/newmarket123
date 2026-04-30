import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

class SupplierPaymentsPage extends StatelessWidget {
  const SupplierPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('دفعات الموردين')),
      body: StreamBuilder<List<drift.TypedResult>>(
        stream: (db.select(db.supplierPayments).join([
          drift.innerJoin(db.suppliers, db.suppliers.id.equalsExp(db.supplierPayments.supplierId)),
        ])
          ..orderBy([drift.OrderingTerm.desc(db.supplierPayments.paymentDate)]))
            .watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const Center(child: Text('لا توجد دفعات مسجلة'));
          }

          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final payment = rows[index].readTable(db.supplierPayments);
              final supplier = rows[index].readTable(db.suppliers);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(supplier.name),
                  subtitle: Text(
                    'التاريخ: ${DateFormat('yyyy-MM-dd').format(payment.paymentDate)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${payment.amount.toStringAsFixed(2)} ر.س',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Text(
                        'COMPLETED', // Status or fixed value
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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
}
