import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/purchases/purchase_provider.dart';
import 'package:supermarket/presentation/widgets/permission_guard.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:go_router/go_router.dart';
import 'package:supermarket/presentation/features/purchases/widgets/purchase_item_row.dart';

// Export supplier and product smart info for use in UI
export 'package:supermarket/presentation/features/purchases/purchase_provider.dart' 
    show SupplierSmartInfo, ProductSmartInfo, PurchaseAlert, PurchaseAlertType;

class NewPurchasePage extends StatefulWidget {
  const NewPurchasePage({super.key});

  @override
  State<NewPurchasePage> createState() => _NewPurchasePageState();
}

class _NewPurchasePageState extends State<NewPurchasePage> {
  final _invoiceNoController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseProvider>().reset();
    });
  }

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PurchaseProvider>();
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة مشتريات جديدة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.reset(),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(provider, db),
                    const SizedBox(height: 20),
                    _buildAlertsPanel(provider),
                    const SizedBox(height: 20),
                    _buildItemsTable(provider, db),
                    const SizedBox(height: 20),
                    _buildAdditionalCosts(provider),
                  ],
                ),
              ),
            ),
            _buildSummaryBar(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(PurchaseProvider provider, AppDatabase db) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<List<Supplier>>(
                    stream: db.select(db.suppliers).watch(),
                    builder: (context, snapshot) {
                      final suppliers = snapshot.data ?? [];
                      return DropdownButtonFormField<Supplier>(
                        decoration: const InputDecoration(labelText: 'المورد'),
                        initialValue: provider.selectedSupplier,
                        items: suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                        onChanged: (val) async {
                          setState(() {});
                          if (val != null) {
                            await provider.setSupplier(val);
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Display supplier smart info
                if (provider.supplierInfo != null)
                  Expanded(
                    child: _buildSupplierInfoCard(provider.supplierInfo!),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _invoiceNoController,
                    decoration: const InputDecoration(labelText: 'رقم الفاتورة (عند المورد)'),
                    onChanged: (val) => provider.invoiceNumber = val,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: provider.selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) setState(() => provider.selectedDate = date);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'تاريخ الفاتورة'),
                      child: Text(DateFormat('yyyy-MM-dd').format(provider.selectedDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                    initialValue: provider.paymentType,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                      DropdownMenuItem(value: 'credit', child: Text('آجل')),
                    ],
                    onChanged: (val) => setState(() => provider.paymentType = val!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTable(PurchaseProvider provider, AppDatabase db) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('الأصناف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () => _showProductPicker(provider, db),
              icon: const Icon(Icons.add),
              label: const Text('إضافة صنف'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Product>>(
          future: db.select(db.products).get(),
          builder: (context, snapshot) {
            final products = snapshot.data ?? [];
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.items.length,
              itemBuilder: (context, index) {
                return PurchaseItemRow(
                  index: index,
                  item: provider.items[index],
                  products: products,
                  onDelete: () => provider.removeItem(index),
                  onChanged: () => setState(() {}),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAdditionalCosts(PurchaseProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تكاليف إضافية', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'الشحن'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => setState(() => provider.shippingCost = double.tryParse(val) ?? 0),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'تكاليف هبوط (Landed)'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => setState(() => provider.landedCosts = double.tryParse(val) ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
              maxLines: 2,
              onChanged: (val) => provider.notes = val,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar(PurchaseProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الإجمالي النهائي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${provider.grandTotal.toStringAsFixed(2)} ريال', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: provider.items.isEmpty ? null : () => _handleSave(provider, post: false),
                    child: const Text('حفظ كمسودة'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PermissionGuard(
                    permissionCode: 'purchases.post',
                    child: ElevatedButton(
                      onPressed: provider.items.isEmpty ? null : () => _handleSave(provider, post: true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text('اعتماد وترحيل'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleSave(PurchaseProvider provider, {required bool post}) async {
    try {
      await provider.savePurchase(post: post);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(post ? 'تم الاعتماد والترحيل بنجاح' : 'تم الحفظ كمسودة')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  /// Build supplier info card showing balance and purchase history
  Widget _buildSupplierInfoCard(SupplierSmartInfo info) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('رصيد المورد: ${info.balance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('عدد الفواتير: ${info.totalInvoices}'),
            Text('إجمالي المشتريات: ${info.totalAmount.toStringAsFixed(2)}'),
            if (info.lastPurchaseDate != null)
              Text('آخر شراء: ${info.lastPurchaseDate!.toString().split(' ')[0]}'),
          ],
        ),
      ),
    );
  }

  /// Build alerts panel
  Widget _buildAlertsPanel(PurchaseProvider provider) {
    if (provider.alerts.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('تنبيهات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          ...provider.alerts.map((alert) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  alert.isWarning ? Icons.warning_amber : Icons.info,
                  color: alert.isWarning ? Colors.orange : Colors.blue,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(child: Text(alert.message)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  void _showProductPicker(PurchaseProvider provider, AppDatabase db) async {
    final products = await db.select(db.products).get();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'بحث عن منتج...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (query) {
                  // Filter products
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  final info = provider.getProductInfo(p.id);
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      title: Text(p.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('السعر الحالي: ${p.buyPrice}'),
                          if (info != null)
                            Text(
                              'المخزون: ${info.currentStock.toStringAsFixed(2)} | متوسط التكلفة: ${info.averageCost.toStringAsFixed(2)}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.add_circle, color: Colors.green),
                      onTap: () {
                        provider.addItemWithInfo(p);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
