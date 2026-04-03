import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/customers/widgets/add_edit_customer_dialog.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

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
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  child: Text(customer.name[0].toUpperCase()),
                ),
                title: Text(customer.name),
                subtitle: Text(customer.phone ?? l10n.noPhone),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n.balanceLabel(customer.balance),
                          style: TextStyle(
                            color: customer.balance > 0
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          l10n.limitLabel(customer.creditLimit),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.payment, color: Colors.teal),
                      tooltip: l10n.payAmount,
                      onPressed: () => _payAmount(db, customer),
                    ),
                    IconButton(
                      icon: const Icon(Icons.receipt_long, color: Colors.blue),
                      tooltip: 'كشف حساب',
                      onPressed: () => context.push('/customers/statement/${customer.id}'),
                    ),
                  ],
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

  Future<void> _payAmount(AppDatabase db, Customer customer) async {
    final l10n = AppLocalizations.of(context)!;
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
      await db.transaction(() async {
        // 1. Update customer balance
        final newBalance = customer.balance - amount;
        await (db.update(db.customers)..where((t) => t.id.equals(customer.id)))
            .write(CustomersCompanion(balance: drift.Value(newBalance)));

        // 2. Record payment in CustomerPayments table
        await db
            .into(db.customerPayments)
            .insert(
              CustomerPaymentsCompanion.insert(
                customerId: customer.id,
                amount: amount,
                paymentDate: drift.Value(DateTime.now()),
                syncStatus: const drift.Value(1),
              ),
            );
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.paymentSuccess)));
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.customerAdded)));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.customerUpdated)));
      }
    }
  }
}
