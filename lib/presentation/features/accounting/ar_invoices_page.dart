import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/presentation/widgets/entity_picker.dart';

class ARInvoicesPage extends StatefulWidget {
  const ARInvoicesPage({super.key});

  @override
  State<ARInvoicesPage> createState() => _ARInvoicesPageState();
}

class _ARInvoicesPageState extends State<ARInvoicesPage> {
  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.arInvoices)),
      drawer: const MainDrawer(),
      body: StreamBuilder<List<ARInvoiceWithCustomer>>(
        stream: _watchARInvoices(db),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final invoices = snapshot.data ?? [];
          if (invoices.isEmpty) {
            return Center(child: Text(l10n.noDataAvailable));
          }

          return ListView.builder(
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final item = invoices[index];
              final invoice = item.invoice;
              final customer = item.customer;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(customer.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${l10n.invoiceNumberLabel}: ${invoice.invoiceNumber}'),
                      Text('${l10n.date}: ${DateFormat.yMMMd().format(invoice.invoiceDate)}'),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        NumberFormat.currency(symbol: l10n.currencySymbol).format(invoice.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        invoice.status,
                        style: TextStyle(
                          color: _getStatusColor(invoice.status),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddInvoiceDialog(context, db),
        child: const Icon(Icons.add),
      ),
    );
  }

  Stream<List<ARInvoiceWithCustomer>> _watchARInvoices(AppDatabase db) {
    final query = db.select(db.aRInvoices).join([
      drift.innerJoin(db.customers, db.customers.id.equalsExp(db.aRInvoices.customerId)),
    ])..orderBy([drift.OrderingTerm.desc(db.aRInvoices.invoiceDate)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return ARInvoiceWithCustomer(
          invoice: row.readTable(db.aRInvoices),
          customer: row.readTable(db.customers),
        );
      }).toList();
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PAID':
        return Colors.green;
      case 'PARTIAL':
        return Colors.orange;
      case 'POSTED':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showAddInvoiceDialog(BuildContext context, AppDatabase db) {
    showDialog(
      context: context,
      builder: (context) => const AddARInvoiceDialog(),
    );
  }
}

class AddARInvoiceDialog extends StatefulWidget {
  const AddARInvoiceDialog({super.key});

  @override
  State<AddARInvoiceDialog> createState() => _AddARInvoiceDialogState();
}

class _AddARInvoiceDialogState extends State<AddARInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  Customer? _selectedCustomer;
  final _invoiceNumberController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _taxAmountController = TextEditingController();
  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.newARInvoice),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomerPicker(
                db: db,
                value: _selectedCustomer,
                onChanged: (c) => setState(() => _selectedCustomer = c),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _invoiceNumberController,
                decoration: InputDecoration(labelText: l10n.invoiceNumberLabel),
                validator: (v) => v == null || v.isEmpty ? l10n.enterNameError : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _totalAmountController,
                decoration: InputDecoration(labelText: l10n.totalAmount),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? l10n.enterAmountError : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _taxAmountController,
                decoration: InputDecoration(labelText: l10n.taxAmount),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(l10n.invoiceDate),
                subtitle: Text(DateFormat.yMMMd().format(_invoiceDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _invoiceDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _invoiceDate = picked);
                },
              ),
              ListTile(
                title: Text(l10n.dueDate),
                subtitle: Text(_dueDate == null ? l10n.unknown : DateFormat.yMMMd().format(_dueDate!)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate() && _selectedCustomer != null) {
              await db.customersDao.createARInvoice(
                ARInvoicesCompanion.insert(
                  customerId: _selectedCustomer!.id,
                  invoiceNumber: _invoiceNumberController.text,
                  invoiceDate: drift.Value(_invoiceDate),
                  dueDate: drift.Value(_dueDate),
                  totalAmount: double.parse(_totalAmountController.text),
                  taxAmount: drift.Value(double.tryParse(_taxAmountController.text) ?? 0.0),
                  status: const drift.Value('POSTED'),
                ),
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.arInvoiceAdded)),
              );
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class ARInvoiceWithCustomer {
  final ARInvoice invoice;
  final Customer customer;

  ARInvoiceWithCustomer({required this.invoice, required this.customer});
}
