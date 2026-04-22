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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.suppliers),
        elevation: 0,
      ),
      drawer: const MainDrawer(),
      body: Column(
        children: [
          _buildSearchBar(l10n, colorScheme),
          Expanded(
            child: StreamBuilder<List<Supplier>>(
              stream: (db.select(db.suppliers)
                    ..where((t) =>
                        t.name.like('%${_searchQuery.toLowerCase()}%') |
                        t.phone.like('%$_searchQuery%')))
                  .watch(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final suppliers = snapshot.data ?? [];
                if (suppliers.isEmpty) {
                  return Center(child: Text(l10n.noSuppliersFound));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = suppliers[index];
                    return _buildSupplierCard(supplier, db, l10n, colorScheme);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSupplier(db),
        icon: const Icon(Icons.add_business),
        label: Text(l10n.addSupplier),
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: l10n.searchSuppliers,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: colorScheme.surface,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildSupplierCard(Supplier supplier, AppDatabase db, AppLocalizations l10n, ColorScheme colorScheme) {
    final bool hasDebt = supplier.balance > 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _editSupplier(db, supplier),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.secondaryContainer,
                    child: Text(supplier.name[0].toUpperCase(), style: TextStyle(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(supplier.contactPerson ?? l10n.noContactPerson, style: TextStyle(color: colorScheme.outline, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("الرصيد", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        "${supplier.balance.toStringAsFixed(2)} ر.س",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: hasDebt ? Colors.red : Colors.green),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.payment),
                        onPressed: () => _payAmount(db, supplier),
                        tooltip: l10n.payAmount,
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.receipt_long),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SupplierStatementPage(supplier: supplier))),
                        tooltip: 'كشف حساب',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reuse original logic methods
  Future<void> _payAmount(AppDatabase db, Supplier supplier) async {
    final l10n = AppLocalizations.of(context)!;
    final userId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.payAmount),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(onPressed: () { final val = double.tryParse(controller.text); if (val != null && val > 0) Navigator.pop(ctx, val); }, child: Text(l10n.save)),
        ],
      ),
    );
    if (amount != null) {
      try {
        await sl<TransactionEngine>().postSupplierPayment(supplierId: supplier.id, amount: amount, paymentMethod: 'cash', userId: userId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.paymentSuccess)));
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); }
    }
  }

  Future<void> _addSupplier(AppDatabase db) async {
    final l10n = AppLocalizations.of(context)!;
    final accountingService = Provider.of<AccountingService>(context, listen: false);
    final companion = await showDialog<SuppliersCompanion>(context: context, builder: (ctx) => const AddEditSupplierDialog());
    if (companion != null) {
      try {
        await db.transaction(() async {
          final accountId = await accountingService.createSupplierAccount(companion.name.value);
          await db.into(db.suppliers).insert(companion.copyWith(accountId: drift.Value(accountId)));
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.supplierAdded)));
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); }
    }
  }

  Future<void> _editSupplier(AppDatabase db, Supplier supplier) async {
    final l10n = AppLocalizations.of(context)!;
    final companion = await showDialog<SuppliersCompanion>(context: context, builder: (ctx) => AddEditSupplierDialog(supplier: supplier));
    if (companion != null) {
      await (db.update(db.suppliers)..where((t) => t.id.equals(supplier.id))).write(companion);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.supplierUpdated)));
    }
  }
}
