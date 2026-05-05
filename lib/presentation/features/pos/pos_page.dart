import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_state.dart';
import 'package:supermarket/presentation/features/pos/widgets/cart_widget.dart';
import 'package:supermarket/presentation/features/pos/widgets/product_grid.dart';
import 'package:supermarket/presentation/features/pos/widgets/product_search_widget.dart';
import 'package:supermarket/presentation/features/pos/widgets/barcode_scanner_dialog.dart';
import 'package:supermarket/presentation/features/pos/widgets/category_selector.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/core/services/communication_service.dart';

class PosPage extends StatelessWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<PosBloc>()..add(LoadCategories()),
      child: const PosView(),
    );
  }
}

class PosView extends StatefulWidget {
  const PosView({super.key});

  @override
  State<PosView> createState() => _PosViewState();
}

class _PosViewState extends State<PosView> {
  final TextEditingController _barcodeController = TextEditingController();

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commService = sl<CommunicationService>();
    
    return BlocListener<PosBloc, PosState>(
      listener: (context, state) {
        if (state is PosCheckoutSuccess) {
          // عرض خيارات إرسال الفاتورة
          _showInvoiceOptions(context, state, commService);
        } else if (state is PosError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نقطة البيع السريع'),
          actions: [
            IconButton(icon: const Icon(Icons.history), onPressed: () => context.push('/sales')),
            IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: () => _openScanner(context)),
          ],
        ),
        body: BlocBuilder<PosBloc, PosState>(
          builder: (context, state) {
            if (state is PosLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is PosError) {
              return Center(child: Text('خطأ في تحميل البيانات: ${state.message}'));
            }
            if (state is PosLoaded) {
              return Row(
                children: [
                  const Expanded(flex: 2, child: CartWidget()),
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ProductSearchWidget(controller: _barcodeController),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: CategorySelector(),
                        ),
                        const Expanded(child: ProductGrid()),
                      ],
                    ),
                  ),
                ],
              );
            }
            return const Center(child: Text('بدء نقطة البيع...'));
          },
        ),
      ),
    );
  }

  Future<void> _openScanner(BuildContext context) async {
    final posBloc = context.read<PosBloc>();
    final result = await showGeneralDialog<String>(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) =>
          const BarcodeScannerDialog(),
    );
    if (result != null && mounted) {
      posBloc.add(AddProductBySku(result));
    }
  }

  void _showInvoiceOptions(
    BuildContext context,
    PosCheckoutSuccess state,
    CommunicationService commService,
  ) async {
    // أولاً إظهار رسالة النجاح
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت عملية البيع بنجاح'), backgroundColor: Colors.green),
    );
    
    // مسح السلة
    context.read<PosBloc>().add(ClearCart());
    
    // عرض خيارات إرسال الفاتورة بعد قليل
    if (!mounted) return;
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final customerName = state.sale.customerId ?? 'عميل نقدي';
    final hasCustomerPhone = state.sale.customerId != null;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🧾 الفاتورة #${state.sale.id.substring(0, 8)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الإجمالي: ${state.sale.totalAmount.toStringAsFixed(2)} ر.س'),
            const SizedBox(height: 16),
            const Text('كيف تريد إرسال الفاتورة؟'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقاً'),
          ),
          // زر طباعة
          IconButton.filledTonal(
            icon: const Icon(Icons.print),
            tooltip: 'طباعة',
            onPressed: () {
              // TODO: تنفيذ الطباعة
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جاري التحضير للطباعة...')),
              );
            },
          ),
          // زر WhatsApp إذا كان هناك عميل
          if (hasCustomerPhone)
            IconButton.filledTonal(
              icon: const Icon(Icons.message, color: Colors.green),
              tooltip: 'WhatsApp',
              onPressed: () async {
                Navigator.pop(ctx);
                // ملاحظة: نحتاج لجلب رقم هاتف العميل من قاعدة البيانات
                // هذا مثال مبسط
                await commService.sendInvoiceViaWhatsApp(
                  phoneNumber: '966500000000', // TODO: جلب الرقم الفعلي
                  invoiceNumber: state.sale.id.substring(0, 8),
                  total: state.sale.totalAmount,
                  customerName: customerName,
                );
              },
            ),
          // زر مشاركة
          IconButton.filledTonal(
            icon: const Icon(Icons.share),
            tooltip: 'مشاركة',
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: تنفيذ المشاركة
            },
          ),
        ],
      ),
    );
  }
}
