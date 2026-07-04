import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/credit_note_service.dart';
import 'package:supermarket/presentation/features/sales/credit_note_provider.dart';
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';
import 'package:supermarket/core/auth/auth_provider.dart';

class CreditNotesPage extends StatefulWidget {
  const CreditNotesPage({super.key});

  @override
  State<CreditNotesPage> createState() => _CreditNotesPageState();
}

class _CreditNotesPageState extends State<CreditNotesPage> {
  String? _selectedCustomerId;
  String? _selectedStatus;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CreditNoteProvider>().loadCreditNotes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إشعارات الدائن'),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: 'فلترة',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _selectedCustomerId = null;
                _selectedStatus = null;
              });
              context.read<CreditNoteProvider>().loadCreditNotes();
            },
            tooltip: 'إعادة تحميل',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showFilters) _buildFiltersPanel(context),
          Expanded(
            child: Consumer<CreditNoteProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(provider.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => provider.loadCreditNotes(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }
                final creditNotes = provider.creditNotes;
                if (creditNotes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 64,
                            color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        const Text('لا توجد إشعارات دائن'),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                  itemCount: creditNotes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final cn = creditNotes[index];
                    return _CreditNoteTile(
                      creditNote: cn,
                      onPost: () => _postCreditNote(context, cn.id),
                      onCancel: () => _cancelCreditNote(context, cn.id),
                      onViewDetails: () =>
                          _showDetailsDialog(context, cn.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('إشعار دائن جديد'),
      ),
    );
  }

  Widget _buildFiltersPanel(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FutureBuilder<List<Customer>>(
                  future: (db.select(db.customers)
                        ..where((c) => c.isActive.equals(true))
                        ..orderBy([(c) => OrderingTerm.asc(c.name)]))
                      .get(),
                  builder: (context, snapshot) {
                    final customers = snapshot.data ?? [];
                    return DropdownButtonFormField<String?>(
                      value: _selectedCustomerId,
                      decoration: const InputDecoration(
                        labelText: 'العميل',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('كل العملاء'),
                        ),
                        ...customers.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedCustomerId = v),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'الحالة',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem<String?>(
                        value: null, child: Text('كل الحالات')),
                    DropdownMenuItem(
                        value: 'DRAFT', child: Text('مسودة')),
                    DropdownMenuItem(
                        value: 'POSTED', child: Text('مرحّل')),
                    DropdownMenuItem(
                        value: 'VOIDED', child: Text('ملغي')),
                  ],
                  onChanged: (v) => setState(() => _selectedStatus = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('بحث'),
              onPressed: () {
                context.read<CreditNoteProvider>().loadCreditNotes(
                      customerId: _selectedCustomerId,
                      status: _selectedStatus,
                    );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _postCreditNote(BuildContext context, String creditNoteId) async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    final provider = context.read<CreditNoteProvider>();
    final success = await provider.postCreditNote(creditNoteId, userId: userId);
    if (!context.mounted) return;
    if (success) {
      AppSnackBar.success(context, 'تم ترحيل سند الائتمان بنجاح');
    } else {
      AppSnackBar.error(context, provider.error ?? 'فشل ترحيل سند الائتمان');
    }
  }

  Future<void> _cancelCreditNote(
      BuildContext context, String creditNoteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: const Text('هل أنت متأكد من إلغاء سند الائتمان؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لا'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final provider = context.read<CreditNoteProvider>();
    final success = await provider.cancelCreditNote(creditNoteId);
    if (!context.mounted) return;
    if (success) {
      AppSnackBar.success(context, 'تم إلغاء سند الائتمان');
    } else {
      AppSnackBar.error(context, provider.error ?? 'فشل الإلغاء');
    }
  }

  Future<void> _showDetailsDialog(
      BuildContext context, String creditNoteId) async {
    final provider = context.read<CreditNoteProvider>();
    final details = await provider.getCreditNoteWithItems(creditNoteId);
    if (!context.mounted) return;
    if (details == null) {
      AppSnackBar.error(context, 'لم يتم العثور على التفاصيل');
      return;
    }

    final db = context.read<AppDatabase>();
    final customer = await (db.select(db.customers)
          ..where((c) => c.id.equals(details.creditNote.customerId)))
        .getSingleOrNull();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفاصيل سند الائتمان'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('الرقم', details.creditNote.invoiceNumber),
                _detailRow('العميل', customer?.name ?? 'غير معروف'),
                _detailRow(
                    'المبلغ',
                    details.creditNote.totalAmount
                        .toStringAsFixed(2)),
                _detailRow('السبب', details.creditNote.reason),
                _detailRow(
                    'الحالة', _statusLabel(details.creditNote.status)),
                _detailRow(
                    'التاريخ',
                    DateFormat('yyyy-MM-dd HH:mm')
                        .format(details.creditNote.createdAt)),
                if (details.creditNote.postedAt != null)
                  _detailRow(
                      'تاريخ الترحيل',
                      DateFormat('yyyy-MM-dd HH:mm')
                          .format(details.creditNote.postedAt!)),
                const Divider(),
                const Text('الأصناف',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                if (details.items.isEmpty)
                  const Text('لا توجد أصناف')
                else
                  ...details.items.map((item) => FutureBuilder<Product?>(
                        future: (db.select(db.products)
                              ..where((p) => p.id.equals(item.productId)))
                            .getSingleOrNull(),
                        builder: (context, snap) {
                          final product = snap.data;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              title: Text(product?.name ?? 'منتج #${item.productId.substring(0, 8)}'),
                              subtitle: Text(
                                  'الكمية: ${item.quantity.toStringAsFixed(0)}  |  '
                                  'السعر: ${item.unitPrice.toStringAsFixed(2)}'),
                              trailing: Text(
                                item.total.toStringAsFixed(2),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final db = context.read<AppDatabase>();

    String? selectedCustomerId;
    String? selectedSaleId;
    final reasonController = TextEditingController();
    final List<_CreditNoteItemEntry> itemEntries = [];

    final customers = await (db.select(db.customers)
          ..where((c) => c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<List<Sale>> loadSales() async {
              if (selectedCustomerId == null) return [];
              return (db.select(db.sales)
                    ..where((s) => s.customerId.equals(selectedCustomerId!))
                    ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
                  .get();
            }

            return AlertDialog(
              title: const Text('إشعار دائن جديد'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'العميل *',
                          isDense: true,
                        ),
                        items: customers
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setDialogState(() {
                            selectedCustomerId = v;
                            selectedSaleId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<Sale>>(
                        future: loadSales(),
                        builder: (context, snapshot) {
                          final sales = snapshot.data ?? [];
                          return DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'فاتورة المبيعات المرجعية *',
                              isDense: true,
                            ),
                            value: selectedSaleId,
                            items: sales
                                .map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(
                                          'فاتورة #${s.id.substring(0, 8)} - ${s.total.toStringAsFixed(2)}'),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedSaleId = v),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                          labelText: 'السبب *',
                          isDense: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('الأصناف',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('إضافة صنف'),
                            onPressed: () async {
                              final products = await (db.select(db.products)
                                    ..orderBy([(p) => OrderingTerm.asc(p.name)]))
                                  .get();
                              if (!ctx.mounted) return;

                              String? chosenProductId;
                              final qtyController =
                                  TextEditingController(text: '1');
                              final priceController =
                                  TextEditingController(text: '0');

                              final added = await showDialog<bool>(
                                context: ctx,
                                builder: (itemCtx) => AlertDialog(
                                  title: const Text('إضافة صنف'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      DropdownButtonFormField<String>(
                                        decoration: const InputDecoration(
                                          labelText: 'المنتج *',
                                          isDense: true,
                                        ),
                                        items: products
                                            .map((p) => DropdownMenuItem(
                                                  value: p.id,
                                                  child: Text(p.name),
                                                ))
                                            .toList(),
                                        onChanged: (v) => chosenProductId = v,
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: qtyController,
                                        decoration: const InputDecoration(
                                          labelText: 'الكمية',
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: priceController,
                                        decoration: const InputDecoration(
                                          labelText: 'سعر الوحدة',
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(itemCtx, false),
                                      child: const Text('إلغاء'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(itemCtx, true),
                                      child: const Text('إضافة'),
                                    ),
                                  ],
                                ),
                              );

                              if (added == true && chosenProductId != null) {
                                final qty = double.tryParse(
                                        qtyController.text) ??
                                    1;
                                final price = double.tryParse(
                                        priceController.text) ??
                                    0;
                                setDialogState(() {
                                  itemEntries.add(_CreditNoteItemEntry(
                                    productId: chosenProductId!,
                                    quantity: qty,
                                    unitPrice: price,
                                  ));
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (itemEntries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('لم تتم إضافة أصناف بعد',
                              style: TextStyle(color: Colors.grey)),
                        )
                      else
                        ...itemEntries.asMap().entries.map((entry) {
                          final i = entry.key;
                          final e = entry.value;
                          return FutureBuilder<Product?>(
                            future: (db.select(db.products)
                                  ..where(
                                      (p) => p.id.equals(e.productId)))
                                .getSingleOrNull(),
                            builder: (context, snap) {
                              final product = snap.data;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  dense: true,
                                  leading: IconButton(
                                    icon: const Icon(Icons.remove_circle,
                                        color: Colors.red),
                                    onPressed: () =>
                                        setDialogState(() => itemEntries.removeAt(i)),
                                  ),
                                  title: Text(product?.name ??
                                      '#${e.productId.substring(0, 8)}'),
                                  subtitle: Text(
                                      'الكمية: ${e.quantity.toStringAsFixed(0)}  |  '
                                      'السعر: ${e.unitPrice.toStringAsFixed(2)}'),
                                  trailing: Text(
                                    (e.quantity * e.unitPrice)
                                        .toStringAsFixed(2),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () {
                    if (selectedCustomerId == null ||
                        selectedSaleId == null ||
                        reasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('يرجى ملء جميع الحقول المطلوبة')),
                      );
                      return;
                    }
                    if (itemEntries.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('يرجى إضافة صنف واحد على الأقل')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('إنشاء'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      if (!context.mounted) return;
      final provider = context.read<CreditNoteProvider>();
      final success = await provider.createCreditNote(
        customerId: selectedCustomerId!,
        saleId: selectedSaleId!,
        reason: reasonController.text.trim(),
        items: itemEntries
            .map((e) => CreditNoteItemData(
                  productId: e.productId,
                  quantity: Decimal.parse(e.quantity.toStringAsFixed(2)),
                  unitPrice: Decimal.parse(e.unitPrice.toStringAsFixed(2)),
                ))
            .toList(),
      );
      if (!context.mounted) return;
      if (success) {
        AppSnackBar.success(context, 'تم إنشاء إشعار الدائن بنجاح');
      } else {
        AppSnackBar.error(
            context, provider.error ?? 'فشل إنشاء إشعار الدائن');
      }
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'DRAFT':
        return 'مسودة';
      case 'POSTED':
        return 'مرحّل';
      case 'VOIDED':
        return 'ملغي';
      default:
        return status;
    }
  }
}

class _CreditNoteTile extends StatelessWidget {
  final CreditNote creditNote;
  final VoidCallback onPost;
  final VoidCallback onCancel;
  final VoidCallback onViewDetails;

  const _CreditNoteTile({
    required this.creditNote,
    required this.onPost,
    required this.onCancel,
    required this.onViewDetails,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'DRAFT':
        return Colors.grey;
      case 'POSTED':
        return Colors.green;
      case 'VOIDED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'DRAFT':
        return 'مسودة';
      case 'POSTED':
        return 'مرحّل';
      case 'VOIDED':
        return 'ملغي';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final color = _statusColor(creditNote.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(Icons.receipt_long, color: color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                creditNote.invoiceNumber,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withAlpha(100)),
              ),
              child: Text(
                _statusLabel(creditNote.status),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            FutureBuilder<Customer?>(
              future: (db.select(db.customers)
                    ..where((c) => c.id.equals(creditNote.customerId)))
                  .getSingleOrNull(),
              builder: (context, snap) {
                return Text('العميل: ${snap.data?.name ?? '...'}',
                    style: const TextStyle(fontSize: 12));
              },
            ),
            const SizedBox(height: 2),
            Text(
              'فاتورة: #${creditNote.saleId.substring(0, 8)}  |  '
              'السبب: ${creditNote.reason}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('yyyy-MM-dd HH:mm').format(creditNote.createdAt),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              creditNote.totalAmount.toStringAsFixed(2),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'details':
                    onViewDetails();
                    break;
                  case 'post':
                    onPost();
                    break;
                  case 'cancel':
                    onCancel();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'details',
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('عرض التفاصيل'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (creditNote.status == 'DRAFT')
                  const PopupMenuItem(
                    value: 'post',
                    child: ListTile(
                      leading: Icon(Icons.check_circle_outline,
                          color: Colors.green),
                      title: Text('ترحيل'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (creditNote.status != 'VOIDED')
                  const PopupMenuItem(
                    value: 'cancel',
                    child: ListTile(
                      leading: Icon(Icons.cancel_outlined, color: Colors.red),
                      title: Text('إلغاء'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _CreditNoteItemEntry {
  final String productId;
  final double quantity;
  final double unitPrice;

  const _CreditNoteItemEntry({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });
}
