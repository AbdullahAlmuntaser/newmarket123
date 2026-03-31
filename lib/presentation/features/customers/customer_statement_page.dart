import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class CustomerStatementPage extends StatelessWidget {
  final Customer customer;
  const CustomerStatementPage({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.customerStatement),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _getCombinedStatement(db, customer.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final statementItems = snapshot.data ?? [];
          if (statementItems.isEmpty) {
            return Center(child: Text(l10n.noTransactionsFound));
          }

          return ListView.builder(
            itemCount: statementItems.length,
            itemBuilder: (context, index) {
              final item = statementItems[index];
              if (item is Sale) {
                return ListTile(
                  title: Text(l10n.sale),
                  subtitle: Text(item.createdAt.toString().split(' ')[0]),
                  trailing: Text(
                    '+\$${item.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              } else if (item is CustomerPayment) {
                return ListTile(
                  title: Text(l10n.payment),
                  subtitle: Text(item.paymentDate.toString().split(' ')[0]),
                  trailing: Text(
                    '-\$${item.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }

  Future<List<dynamic>> _getCombinedStatement(
      AppDatabase db, String customerId) async {
    final sales = await db.salesDao.getSalesForCustomer(customerId);
    final payments = await db.customersDao.getPaymentsForCustomer(customerId);

    final combined = [...sales, ...payments];
    combined.sort((a, b) {
      DateTime dateA;
      DateTime dateB;

      if (a is Sale) {
        dateA = a.createdAt;
      } else {
        dateA = (a as CustomerPayment).paymentDate;
      }

      if (b is Sale) {
        dateB = b.createdAt;
      } else {
        dateB = (b as CustomerPayment).paymentDate;
      }

      return dateB.compareTo(dateA); // Sort descending
    });

    return combined;
  }
}
