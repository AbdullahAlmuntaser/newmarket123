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
  bool _isFilterExpanded = false;
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
      appBar: AppBar(title: Text(l10n.customers), elevation: 0),
      drawer: const MainDrawer(),
      body: Column(
        children: [
          _buildSummaryCards(db, l10n, colorScheme),
          _buildCollapsibleFilter(l10n, colorScheme),
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
                        Icon(
                          Icons.person_off,
                          size: 64,
                          color: colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(l10n.noCustomersFound),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
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

  Widget _buildSummaryCards(
    AppDatabase db,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(50),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          _summaryCard(
            "العدد",
            db.select(db.customers).watch().map((l) => l.length.toString()),
            Icons.people_outline,
            colorScheme.primary,
          ),
          const SizedBox(width: 12),
          _summaryCard(
            "إجمالي المديونية",
            _getTotalBalance(db),
            Icons.account_balance_wallet_outlined,
            colorScheme.error,
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    String title,
    Stream<String> valueStream,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withAlpha(50)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              StreamBuilder<String>(
                stream: valueStream,
                builder: (context, snap) => Text(
                  snap.data ?? '0.0',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleFilter(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: l10n.searchCustomers,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        ExpansionTile(
          initiallyExpanded: _isFilterExpanded,
          onExpansionChanged: (v) => setState(() => _isFilterExpanded = v),
          title: const Text('تصفية النتائج', style: TextStyle(fontSize: 14)),
          leading: const Icon(Icons.tune, size: 20),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  _filterChip("الكل", "ALL"),
                  _filterChip("تجزئة", "RETAIL"),
                  _filterChip("جملة", "WHOLESALE"),
                  _filterChip("VIP", "VIP"),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final bool isSelected = _selectedType == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null),
      ),
      selected: isSelected,
      onSelected: (v) => setState(() => _selectedType = value),
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildCustomerCard(
    Customer customer,
    AppDatabase db,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final bool isDebit = customer.balance > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _editCustomer(db, customer),
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
                    child: Text(
                      customer.name[0].toUpperCase(),
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          customer.phone ?? l10n.noPhone,
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildTypeBadge(customer.customerType),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "الرصيد",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        "${customer.balance.toStringAsFixed(2)} ر.س",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
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
    Color color = Colors.grey;
    String label = type;
    switch (type) {
      case 'RETAIL':
        color = Colors.blue;
        label = "تجزئة";
        break;
      case 'WHOLESALE':
        color = Colors.orange;
        label = "جملة";
        break;
      case 'VIP':
        color = Colors.purple;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Stream<String> _getTotalBalance(AppDatabase db) {
    return db
        .select(db.customers)
        .watch()
        .map(
          (customers) => customers
              .fold(0.0, (sum, item) => sum + item.balance)
              .toStringAsFixed(2),
        );
  }

  Stream<List<Customer>> _getFilteredStream(AppDatabase db) {
    return (db.select(db.customers)..where((t) {
          final matchesSearch =
              t.name.like('%${_searchQuery.toLowerCase()}%') |
              t.phone.like('%$_searchQuery%');
          final matchesType = _selectedType == 'ALL'
              ? const drift.Constant(true)
              : t.customerType.equals(_selectedType);
          return matchesSearch & matchesType & t.isActive.equals(true);
        }))
        .watch();
  }

  // Reuse original logic methods
  Future<void> _showPayAmountDialog(AppDatabase db, Customer customer) async {
    final l10n = AppLocalizations.of(context)!;
    final userId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.id;
    _payAmountController.clear();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.payAmount),
        content: TextField(
          controller: _payAmountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المبلغ'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(_payAmountController.text);
              if (val != null && val > 0) Navigator.pop(ctx, val);
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        }
      }
    }
  }

  Future<void> _addCustomer(AppDatabase db) async {
    final companion = await showDialog<CustomersCompanion>(
      context: context,
      builder: (ctx) => const AddEditCustomerDialog(),
    );
    if (companion != null) {
      try {
        await db.customersDao.insertCustomerWithAccount(companion);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تمت الإضافة')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        }
      }
    }
  }

  Future<void> _editCustomer(AppDatabase db, Customer customer) async {
    final companion = await showDialog<CustomersCompanion>(
      context: context,
      builder: (ctx) => AddEditCustomerDialog(customer: customer),
    );
    if (companion != null) {
      await (db.update(
        db.customers,
      )..where((t) => t.id.equals(customer.id))).write(companion);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم التحديث')));
      }
    }
  }
}
