import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'widgets/add_edit_supplier_dialog.dart';
import 'widgets/supplier_payment_dialog.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/services/communication_service.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  String _searchQuery = '';
  int _currentPage = 0;
  int _totalSuppliers = 0;
  bool _isLoadingMore = false;
  final int _pageSize = 30;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadTotalCount();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreItems) {
        _loadMore();
      }
    }
  }

  bool get _hasMoreItems => (_currentPage + 1) * _pageSize < _totalSuppliers;

  Future<void> _loadTotalCount() async {
    final db = context.read<AppDatabase>();
    final query = db.select(db.suppliers)
      ..where((t) =>
          (t.name.like('%${_searchQuery.toLowerCase()}%') |
              t.phone.like('%$_searchQuery%')) &
          t.isActive.equals(true));
    final count = await query.get();
    setState(() => _totalSuppliers = count.length);
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    setState(() {
      _currentPage++;
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.suppliers), elevation: 0),
      drawer: const MainDrawer(),
      body: Column(
        children: [
          _buildSearchBar(l10n, colorScheme),
          Expanded(
            child: StreamBuilder<List<Supplier>>(
              stream: (db.select(db.suppliers)
                    ..where(
                      (t) =>
                          (t.name.like('%${_searchQuery.toLowerCase()}%') |
                              t.phone.like('%$_searchQuery%')) &
                          t.isActive.equals(true),
                    )
                    ..limit(_pageSize, offset: _currentPage * _pageSize))
                  .watch(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final suppliers = snapshot.data ?? [];
                if (suppliers.isEmpty && _currentPage == 0) {
                  return Center(child: Text(l10n.noSuppliersFound));
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                  itemCount: suppliers.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == suppliers.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
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
        onChanged: (value) => setState(() {
          _searchQuery = value;
          _currentPage = 0;
          _totalSuppliers = 0;
        }),
      ),
    );
  }

  Widget _buildSupplierCard(
    Supplier supplier,
    AppDatabase db,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final bool hasDebt = supplier.balance > Decimal.zero;
    final commService = sl<CommunicationService>();

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
                    child: Text(
                      supplier.name[0].toUpperCase(),
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
                          supplier.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          supplier.contactPerson ?? l10n.noContactPerson,
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
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
                      const Text(
                        "الرصيد",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        "${supplier.balance.toStringAsFixed(2)} ر.س",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: hasDebt ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // زر الاتصال الهاتفي
                      if (supplier.phone != null && supplier.phone!.isNotEmpty)
                        IconButton.filledTonal(
                          icon: const Icon(Icons.phone),
                          onPressed: () =>
                              commService.makePhoneCall(supplier.phone!),
                          tooltip: 'اتصال',
                        ),
                      const SizedBox(width: 4),
                      // زر WhatsApp
                      if (supplier.phone != null && supplier.phone!.isNotEmpty)
                        IconButton.filledTonal(
                          icon: const Icon(Icons.message, color: Colors.green),
                          onPressed: () => commService.sendWhatsAppMessage(
                            phoneNumber: supplier.phone!,
                            message: 'مرحباً، نود التواصل بخصوص الطلبات.',
                          ),
                          tooltip: 'WhatsApp',
                        ),
                      const SizedBox(width: 4),
                      // زر الدفع
                      IconButton.filledTonal(
                        icon: const Icon(Icons.payment),
                        onPressed: () => _payAmount(db, supplier),
                        tooltip: l10n.payAmount,
                      ),
                      const SizedBox(width: 4),
                      // زر كشف الحساب
                      IconButton.filledTonal(
                        icon: const Icon(Icons.receipt_long),
                        onPressed: () => context.push(
                          '/suppliers/statement/${supplier.id}',
                          extra: supplier,
                        ),
                        tooltip: 'كشف حساب',
                      ),
                      const SizedBox(width: 4),
                      // زر الحذف
                      IconButton.filledTonal(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteSupplier(supplier),
                        tooltip: l10n.deleteSupplier,
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
    final userId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.id;
    final engine = sl<TransactionEngine>();

    try {
      final outstandingPurchases =
          await engine.getOutstandingPurchases(supplier.id);
      if (!mounted) return;

      if (outstandingPurchases.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد فواتير مستحقة لهذا المورد')),
        );
        return;
      }

      final result = await showDialog<SupplierPaymentResult>(
        context: context,
        builder: (ctx) => SupplierPaymentDialog(
          supplier: supplier,
          outstandingPurchases: outstandingPurchases,
        ),
      );

      if (result != null) {
        await engine.postSupplierPaymentWithAllocations(
          supplierId: supplier.id,
          amount: result.totalAmount,
          paymentMethod: 'cash',
          note: result.note,
          userId: userId,
          allocations: result.allocations,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.paymentSuccess)));
        }
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('FOREIGN KEY')
            ? 'تعذر إنشاء حساب المورد لأن الفرع أو الحساب الأب غير مهيأ. تمت محاولة التهيئة التلقائية، يرجى إعادة المحاولة.'
            : 'خطأ: $e';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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
      builder: (ctx) => const AddEditSupplierDialog(),
    );
    if (companion != null) {
      try {
        await db.transaction(() async {
          final accountId = await accountingService.createSupplierAccount(
            companion.name.value,
          );
          await db
              .into(db.suppliers)
              .insert(companion.copyWith(accountId: drift.Value(accountId)));
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.supplierAdded)));
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

  Future<void> _editSupplier(AppDatabase db, Supplier supplier) async {
    final l10n = AppLocalizations.of(context)!;
    final companion = await showDialog<SuppliersCompanion>(
      context: context,
      builder: (ctx) => AddEditSupplierDialog(supplier: supplier),
    );
    if (companion != null) {
      await (db.update(
        db.suppliers,
      )..where((t) => t.id.equals(supplier.id)))
          .write(companion);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.supplierUpdated)));
      }
    }
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSupplier),
        content: Text(l10n.confirmDeleteSupplier(supplier.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await sl<AppDatabase>().suppliersDao.deleteSupplier(supplier);
        if (mounted) {
          await sl<AuditService>().logDelete(
            'Supplier',
            supplier.id,
            details: 'Supplier deleted: ${supplier.name}',
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.supplierDeleted)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.failedToDeleteSupplier}: $e')),
          );
        }
      }
    }
  }
}
