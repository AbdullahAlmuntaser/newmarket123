import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/suppliers_dao.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/presentation/widgets/entity_picker.dart';

class SupplierLedgerPage extends StatefulWidget {
  const SupplierLedgerPage({super.key});

  @override
  State<SupplierLedgerPage> createState() => _SupplierLedgerPageState();
}

class _SupplierLedgerPageState extends State<SupplierLedgerPage> {
  Supplier? _selectedSupplier;
  List<SupplierTransaction> _transactions = [];
  bool _isLoading = false;

  Future<void> _fetchStatement(AppDatabase db) async {
    if (_selectedSupplier == null) return;
    setState(() => _isLoading = true);
    final txs = await db.suppliersDao.getSupplierStatement(_selectedSupplier!.id);
    setState(() {
      _transactions = txs.reversed.toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.supplierLedger)),
      drawer: const MainDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SupplierPicker(
              db: db,
              value: _selectedSupplier,
              onChanged: (s) {
                setState(() => _selectedSupplier = s);
                _fetchStatement(db);
              },
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_selectedSupplier == null)
            Expanded(child: Center(child: Text(l10n.selectSupplier)))
          else if (_transactions.isEmpty)
            Expanded(child: Center(child: Text(l10n.noTransactionsFound)))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final tx = _transactions[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      title: Text(tx.description),
                      subtitle: Text(DateFormat.yMMMd().format(tx.date)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (tx.debit > 0)
                            Text(
                              '+${NumberFormat.currency(symbol: '').format(tx.debit)}',
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          if (tx.credit > 0)
                            Text(
                              '-${NumberFormat.currency(symbol: '').format(tx.credit)}',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
