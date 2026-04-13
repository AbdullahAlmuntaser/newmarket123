import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'widgets/add_edit_supplier_dialog.dart';
import 'supplier_statement_page.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/core/services/accounting_service.dart';

import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/core/auth/auth_provider.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.suppliers),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.searchSuppliers,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                filled: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      drawer: const MainDrawer(),
      body: StreamBuilder<List<Supplier>>(
        stream:
            (db.select(db.suppliers)..where(
                  (t) =>
                      t.name.like('%${_searchQuery.toLowerCase()}%') |
                      t.phone.like('%$_searchQuery%'),
                ))
                .watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final suppliers = snapshot.data ?? [];
          if (suppliers.isEmpty) {
            return Center(child: Text(l10n.noSuppliersFound));
          }
          return ListView.separated(
            itemCount: suppliers.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  child: Text(supplier.name[0].toUpperCase()),
                ),
                title: Text(supplier.name),
                subtitle: Text(supplier.contactPerson ?? l10n.noContactPerson),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.balanceLabel(supplier.balance),
                      style: TextStyle(
                        color: supplier.balance > 0 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.payment, color: Colors.teal),
                      tooltip: l10n.payAmount,
                      onPressed: () => _payAmount(db, supplier),
                    ),
                    IconButton(
                      icon: const Icon(Icons.receipt_long, color: Colors.blue),
                      tooltip: 'كشف حساب',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SupplierStatementPage(supplier: supplier),
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () => _editSupplier(db, supplier),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addSupplier(db),
        child: const Icon(Icons.add_business),
      ),
    );
  }

  Future<void> _payAmount(AppDatabase db, Supplier supplier) async {
    final l10n = AppLocalizations.of(context)!;
    final userId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    final controller = TextEditingController();

    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.payAmount),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.paymentAmount,
            suffixText: 'SAR',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                Navigator.pop(context, val);
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.enterAmountError)));
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (amount != null) {
      try {
        await sl<TransactionEngine>().postSupplierPayment(
          supplierId: supplier.id,
          amount: amount,
          paymentMethod: 'cash',
          userId: userId,
        );

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.paymentSuccess)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _addSupplier(AppDatabase db) async {
    final l10n = AppLocalizations.of(context)!;
    final accountingService = Provider.of<AccountingService>(
      context,
      listen: false,
    );

    final companion = await showDialog<SuppliersCompanion>(
      context: context,
      builder: (context) => const AddEditSupplierDialog(),
    );

    if (companion != null) {
      try {
        await db.transaction(() async {
          // 1. Create GL Account for the supplier
          final accountId = await accountingService.createSupplierAccount(
            companion.name.value,
          );

          // 2. Insert supplier with the new accountId
          final finalCompanion = companion.copyWith(
            accountId: drift.Value(accountId),
          );
          await db.into(db.suppliers).insert(finalCompanion);
        });

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.supplierAdded)));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _editSupplier(AppDatabase db, Supplier supplier) async {
    final l10n = AppLocalizations.of(context)!;
    final companion = await showDialog<SuppliersCompanion>(
      context: context,
      builder: (context) => AddEditSupplierDialog(supplier: supplier),
    );

    if (companion != null) {
      await (db.update(
        db.suppliers,
      )..where((t) => t.id.equals(supplier.id))).write(companion);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.supplierUpdated)));
      }
    }
  }
}
