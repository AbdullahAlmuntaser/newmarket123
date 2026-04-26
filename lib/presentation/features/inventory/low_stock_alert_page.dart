import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart';

class LowStockAlertPage extends StatelessWidget {
  const LowStockAlertPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = sl<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: const Text('تنبيهات انخفاض المخزون')),
      body: StreamBuilder<List<Product>>(
        stream: db.watchLowStockProducts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data!;
          if (products.isEmpty) {
            return const Center(child: Text('جميع المخزون ضمن الحدود الآمنة'));
          }

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.orange),
                  title: Text(p.name),
                  subtitle: Text(
                    'الرصيد الحالي: ${p.stock} | حد التنبيه: ${p.alertLimit}',
                  ),
                  trailing: const Icon(Icons.inventory),
                  onTap: () {
                    // Logic to open stock replenishment dialog
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
