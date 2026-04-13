import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/customers/widgets/add_edit_customer_dialog.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/presentation/features/customers/widgets/customer_trailing_widgets.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/core/auth/auth_provider.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String _searchQuery = '';
  String _selectedType = 'ALL';
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
    final theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.customers),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      drawer: const MainDrawer(),
      body: Column(
        children: [
          _buildSummaryCards(db, l10n, colorScheme),
          _buildSearchBar(l10n, colorScheme),
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: _getFilteredStream(db),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final customers = snapshot.data ?? [];
                if (customers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 64, color: colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(l10n.noCustomersFound),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return _buildCustomerCard(customer, db, l10n, colorScheme);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCustomer(db),
        icon: const Icon(Icons.person_add),
        label: Text(l10n.addCustomer),
      ),
    );
  }

  Widget _buildSummaryCards(AppDatabase db, AppLocalizations l10n, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(77), // Replaced withOpacity(0.3)
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          _summaryItem("العملاء", db.select(db.customers).watch().map((l) => l.length.toString()), Icons.people, colorScheme.primary),
          _summaryItem("إجمالي المديونية", _getTotalBalance(db), Icons.account_balance_wallet, colorScheme.error),
        ],
      ),
    );
  }

  Widget _summaryItem(String title, Stream<String> valueStream, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              StreamBuilder<String>(
                stream: valueStream,
                builder: (context, snap) => Text(
                  snap.data ?? '0.0',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Stream<String> _getTotalBalance(AppDatabase db) {
    return db.select(db.customers).watch().map((customers) {
      double total = customers.fold(0, (sum, item) => sum + item.balance);
      return total.toStringAsFixed(2);
    });
  }

  Widget _buildSearchBar(AppLocalizations l10n, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: l10n.searchCustomers,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = '')) 
            : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          filled: true,
          fillColor: colorScheme.surface,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer, AppDatabase db, AppLocalizations l10n, ColorScheme colorScheme) {
    final bool isDebit = customer.balance > 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: () => _editCustomer(db, customer),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _getTypeColor(customer.customerType).withAlpha(26),
                    child: Text(
                      customer.name[0].toUpperCase(),
                      style: TextStyle(color: _getTypeColor(customer.customerType), fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(customer.phone ?? l10n.noPhone, style: TextStyle(color: colorScheme.outline, fontSize: 13)),
                        if (customer.taxNumber != null && customer.taxNumber!.isNotEmpty)
                          Text("ضريبي: ${customer.taxNumber}", style: TextStyle(color: colorScheme.primary, fontSize: 12)),
                      ],
                    ),
                  ),
                  _buildTypeBadge(customer.customerType),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("الرصيد الحالي", style: TextStyle(fontSize: 12)),
                      Text(
                        "${customer.balance.toStringAsFixed(2)} ${l10n.currencySymbol}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDebit ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  CustomerTrailingWidgets(
                    customer: customer,
                    db: db,
                    l10n: l10n,
                    onPayAmount: _showPayAmountDialog,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getTypeColor(type).withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getTypeColor(type).withAlpha(128)),
      ),
      child: Text(
        _getTypeLabel(type),
        style: TextStyle(color: _getTypeColor(type), fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'RETAIL': return Colors.blue;
      case 'WHOLESALE': return Colors.orange;
      case 'VIP': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'RETAIL': return "تجزئة";
      case 'WHOLESALE': return "جملة";
      case 'VIP': return "VIP";
      default: return type;
    }
  }

  Stream<List<Customer>> _getFilteredStream(AppDatabase db) {
    return (db.select(db.customers)..where((t) {
      final matchesSearch = t.name.like('%${_searchQuery.toLowerCase()}%') | 
                           t.phone.like('%$_searchQuery%') |
                           t.taxNumber.like('%$_searchQuery%');
      final matchesType = _selectedType == 'ALL' ? const drift.Constant(true) : t.customerType.equals(_selectedType);
      return matchesSearch & matchesType & t.isActive.equals(true);
    })).watch();
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تصفية العملاء"),
        content: RadioGroup<String>(
          groupValue: _selectedType,
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedType = val);
              Navigator.pop(context);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _filterOption("الكل", "ALL"),
              _filterOption("تجزئة", "RETAIL"),
              _filterOption("جملة", "WHOLESALE"),
              _filterOption("VIP", "VIP"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterOption(String title, String value) {
    return RadioListTile<String>(
      title: Text(title),
      value: value,
    );
  }

  Future<void> _showPayAmountDialog(AppDatabase db, Customer customer) async {
    final l10n = AppLocalizations.of(context)!;
    final userId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    _payAmountController.clear();

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
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(_payAmountController.text);
              if (val != null && val > 0) Navigator.pop(dialogContext, val);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (amount != null) {
      try {
        await sl<TransactionEngine>().postCustomerPayment(
          customerId: customer.id,
          amount: amount,
          paymentMethod: 'cash', // Default to cash for now
          userId: userId,
        );
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.paymentSuccess)));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      try {
        await db.customersDao.insertCustomerWithAccount(companion);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.customerAdded)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
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
      await (db.update(db.customers)..where((t) => t.id.equals(customer.id))).write(companion);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.customerUpdated)));
    }
  }
}
