import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:decimal/decimal.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_state.dart';

class PosReturnWidget extends StatefulWidget {
  const PosReturnWidget({super.key});

  @override
  State<PosReturnWidget> createState() => _PosReturnWidgetState();
}

class _PosReturnWidgetState extends State<PosReturnWidget> {
  final _saleReferenceController = TextEditingController();

  @override
  void dispose() {
    _saleReferenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        if (state is! PosLoaded) return const SizedBox.shrink();

        if (!state.isReturnMode) {
          return _buildReturnToggle(state);
        }

        return _buildReturnPanel(state);
      },
    );
  }

  Widget _buildReturnToggle(PosLoaded state) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: OutlinedButton.icon(
        onPressed: () {
          context.read<PosBloc>().add(const ToggleReturnMode(true));
        },
        icon: const Icon(Icons.keyboard_return, color: Colors.orange),
        label:
            const Text('وضع المرتجعات', style: TextStyle(color: Colors.orange)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.orange),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildReturnPanel(PosLoaded state) {
    return Card(
      margin: const EdgeInsets.all(8),
      color: Colors.orange.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildReturnHeader(state),
          if (state.originalSale == null)
            _buildSaleLookup()
          else ...[
            _buildOriginalSaleInfo(state),
            _buildReturnItemsList(state),
            _buildReturnSummary(state),
            _buildReturnActions(state),
          ],
        ],
      ),
    );
  }

  Widget _buildReturnHeader(PosLoaded state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.keyboard_return, color: Colors.orange),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'وضع المرتجعات',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.orange,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.orange),
            tooltip: 'إلغاء وضع المرتجعات',
            onPressed: () {
              context.read<PosBloc>().add(ClearReturn());
              _saleReferenceController.clear();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaleLookup() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'أدخل رقم الفاتورة الأصلية للبحث',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _saleReferenceController,
                  decoration: const InputDecoration(
                    hintText: 'رقم الفاتورة...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _lookupSale(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _lookupSale,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('بحث'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOriginalSaleInfo(PosLoaded state) {
    final sale = state.originalSale!;
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.receipt_long, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الفاتورة #${sale.id.substring(0, 8)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'التاريخ: ${sale.createdAt.day}/${sale.createdAt.month}/${sale.createdAt.year}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '${sale.total.toStringAsFixed(2)} ر.س',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnItemsList(PosLoaded state) {
    return Expanded(
      child: state.returnItems.isEmpty
          ? const Center(
              child: Text(
                'لا توجد أصناف في الفاتورة الأصلية',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: state.returnItems.length,
              itemBuilder: (context, index) {
                final item = state.returnItems[index];
                return _buildReturnItemCard(item, index);
              },
            ),
    );
  }

  Widget _buildReturnItemCard(ReturnItem item, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'المنتج #${item.productId.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${item.unitPrice.toStringAsFixed(2)} ر.س / وحدة',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('الكمية المرتجعة: '),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: item.quantity > Decimal.zero
                      ? () {
                          final newQty = item.quantity - Decimal.one;
                          if (newQty >= Decimal.zero) {
                            context.read<PosBloc>().add(
                                  AddReturnItem(
                                    productId: item.productId,
                                    quantity: newQty,
                                    unitPrice: item.unitPrice,
                                    reason: item.reason,
                                  ),
                                );
                          }
                        }
                      : null,
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    item.quantity.toStringAsFixed(0),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () {
                    context.read<PosBloc>().add(
                          AddReturnItem(
                            productId: item.productId,
                            quantity: item.quantity + Decimal.one,
                            unitPrice: item.unitPrice,
                            reason: item.reason,
                          ),
                        );
                  },
                ),
                const Spacer(),
                Text(
                  '${item.total.toStringAsFixed(2)} ر.س',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              decoration: const InputDecoration(
                hintText: 'سبب الإرجاع...',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (value) {
                context.read<PosBloc>().add(
                      AddReturnItem(
                        productId: item.productId,
                        quantity: item.quantity,
                        unitPrice: item.unitPrice,
                        reason: value,
                      ),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnSummary(PosLoaded state) {
    final returnTotal = state.returnTotal;
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'إجمالي المرتجع:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${returnTotal.toStringAsFixed(2)} ر.س',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnActions(PosLoaded state) {
    final hasItemsToReturn =
        state.returnItems.any((i) => i.quantity > Decimal.zero);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                context.read<PosBloc>().add(ClearReturn());
                _saleReferenceController.clear();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: hasItemsToReturn && !state.isProcessingCheckout
                  ? () => _processReturn(state)
                  : null,
              icon: state.isProcessingCheckout
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(state.isProcessingCheckout
                  ? 'جاري المعالجة...'
                  : 'تنفيذ المرتجع'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _lookupSale() {
    final reference = _saleReferenceController.text.trim();
    if (reference.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل رقم الفاتورة أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    context.read<PosBloc>().add(LookupOriginalSale(reference));
  }

  void _processReturn(PosLoaded state) {
    if (state.originalSale == null) return;

    final itemsToReturn =
        state.returnItems.where((i) => i.quantity > Decimal.zero).toList();

    if (itemsToReturn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدد كمية الصناديق المرتجعة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final hasReasons = itemsToReturn.every((i) => i.reason.isNotEmpty);
    if (!hasReasons) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تنبيه'),
          content: const Text('بعض الأصناف بدون سبب إرجاع. هل تريد المتابعة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeReturn(state);
              },
              child: const Text('متابعة'),
            ),
          ],
        ),
      );
    } else {
      _executeReturn(state);
    }
  }

  void _executeReturn(PosLoaded state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد المرتجع'),
        content: Text(
          'هل أنت متأكد من إرجاع ${state.returnTotal.toStringAsFixed(2)} ر.س؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<PosBloc>().add(
                    ProcessReturn(
                      state.originalSale!.id,
                      customerId: state.originalSale!.customerId,
                    ),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد المرتجع'),
          ),
        ],
      ),
    );
  }
}
