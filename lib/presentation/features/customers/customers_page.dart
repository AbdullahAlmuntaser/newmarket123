import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/customers/widgets/add_edit_customer_dialog.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/presentation/features/customers/widgets/customer_trailing_widgets.dart'; // Import the new widget
import 'package:supermarket/core/services/accounting_service.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String _searchQuery = '';
  final TextEditingController _payAmountController = TextEditingController();

  @override
  void dispose() {
    _payAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.customers),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.searchCustomers,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      drawer: const MainDrawer(),
      body: StreamBuilder<List<Customer>>(
        stream:
            (db.select(db.customers)..where(
                  (t) =>
                      t.name.like('%${_searchQuery.toLowerCase()}%') |
                      t.phone.like('%$_searchQuery%'),
                ))
                .watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final customers = snapshot.data ?? [];
          if (customers.isEmpty) {
            return Center(child: Text(l10n.noCustomersFound));
          }
          return ListView.separated(
            itemCount: customers.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final customer = customers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Text(customer.name[0].toUpperCase(), style: TextStyle(color: colorScheme.onSecondaryContainer)),
                ),
                title: Text(customer.name),
                subtitle: Text(customer.phone ?? l10n.noPhone),
                trailing: CustomerTrailingWidgets(
                  customer: customer,
                  db: db,
                  l10n: l10n,
                  onPayAmount: _showPayAmountDialog,
                ),
                onTap: () => _editCustomer(db, customer),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCustomer(db),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  // This function will be passed to CustomerTrailingWidgets
  Future<void> _showPayAmountDialog(AppDatabase db, Customer customer) async {
    final l10n = AppLocalizations.of(context)!;
    final accountingService = Provider.of<AccountingService>(context, listen: false);
    _payAmountController.clear(); // Clear previous input

    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.payAmount),
        content: TextField(
          controller: _payAmountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.paymentAmount,
            suffixText: l10n.currencySymbol,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(_payAmountController.text);
              if (val != null && val > 0) {
                Navigator.pop(dialogContext, val);
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(l10n.enterAmountError)),
                );
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (amount != null) {
      try {
        await db.transaction(() async {
          // 1. Update customer balance
          final newBalance = customer.balance - amount;
          await (db.update(db.customers)..where((t) => t.id.equals(customer.id)))
              .write(CustomersCompanion(balance: drift.Value(newBalance)));

          // 2. Record payment in CustomerPayments table
          await db.into(db.customerPayments).insert(
                CustomerPaymentsCompanion.insert(
                  customerId: customer.id,
                  amount: amount,
                  paymentDate: drift.Value(DateTime.now()),
                  syncStatus: const drift.Value(1),
                ),
              );

          // 3. Post to General Ledger
          await accountingService.recordCustomerPayment(
            customerId: customer.id,
            amount: amount,
            paymentAccountCode: AccountingService.codeCash, // Assuming cash payment for now
          );
        });

        if (!mounted) return; // Check if the widget is still mounted before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.paymentSuccess)));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _addCustomer(AppDatabase db) async {
    final l10n = AppLocalizations.of(context)!;
    final companion = await showDialog<CustomersCompanion>(
      context: context,
      builder: (context) => const AddEditCustomerDialog(),
    );

    if (companion != null) {
      await db.into(db.customers).insert(companion);
      if (!mounted) return; // Check if the widget is still mounted before showing SnackBar
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.customerAdded)));
    }
  }

  Future<void> _editCustomer(AppDatabase db, Customer customer) async {
    final l10n = AppLocalizations.of(context)!;
    final companion = await showDialog<CustomersCompanion>(
      context: context,
      builder: (context) => AddEditCustomerDialog(customer: customer),
    );

    if (companion != null) {
      await (db.update(
        db.customers,
      )..where((t) => t.id.equals(customer.id))).write(companion);
      if (!mounted) return; // Check if the widget is still mounted before showing SnackBar
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.customerUpdated)));
    }
  }
}
