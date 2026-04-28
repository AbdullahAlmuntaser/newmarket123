import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;

class SupplierStatementPage extends StatelessWidget {
  final Supplier supplier;

  const SupplierStatementPage({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text('كشف حساب المورد: ${supplier.name}')),
      body: Column(
        children: [
          _buildSummaryHeader(context, l10n),
          Expanded(
            child: StreamBuilder<List<dynamic>>(
              stream: _getCombinedStatementStream(db),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return const Center(child: Text('لا توجد معاملات بعد.'));
                }
                return ListView.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    if (tx is Purchase) {
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.orangeAccent,
                          child: Icon(Icons.receipt, color: Colors.white),
                        ),
                        title: Text(
                          'فاتورة مشتريات ${tx.invoiceNumber != null ? '#${tx.invoiceNumber}' : ''}',
                        ),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(tx.date),
                        ),
                        trailing: Text(
                          '+${tx.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    } else if (tx is SupplierPayment) {
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.payment, color: Colors.white),
                        ),
                        title: const Text('دفعة للمورد'),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(tx.paymentDate),
                        ),
                        trailing: Text(
                          '-${tx.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.green,
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
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        children: [
          Text(
            'الرصيد المستحق للمورد',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${supplier.balance.toStringAsFixed(2)} SAR',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: supplier.balance > 0 ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<dynamic>> _getCombinedStatementStream(AppDatabase db) {
    final purchasesStream =
        (db.select(db.purchases)..where(
              (t) => t.supplierId.equals(supplier.id) & t.isCredit.equals(true),
            ))
            .watch();

    return purchasesStream.asyncMap((purchases) async {
      final payments = await (db.select(
        db.supplierPayments,
      )..where((t) => t.supplierId.equals(supplier.id))).get();

      final List<dynamic> combined = [...purchases, ...payments];
      combined.sort((a, b) {
        final dateA = a is Purchase
            ? a.date
            : (a as SupplierPayment).paymentDate;
        final dateB = b is Purchase
            ? b.date
            : (b as SupplierPayment).paymentDate;
        return dateB.compareTo(dateA); // Newest first
      });
      return combined;
    });
  }
}
