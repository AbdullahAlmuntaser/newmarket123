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
import 'package:supermarket/core/services/quick_customer_service.dart';
import 'package:supermarket/core/utils/printer_helper.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:share_plus/share_plus.dart';

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
    final quickCustomerService = sl<QuickCustomerService>();

    return BlocListener<PosBloc, PosState>(
      listener: (context, state) {
        if (state is PosCheckoutSuccess) {
          _showInvoiceOptions(context, state, commService, quickCustomerService);
        } else if (state is PosError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: BlocBuilder<PosBloc, PosState>(
        builder: (context, state) {
          final bool isWholesale = state is PosLoaded && state.isWholesaleMode;

          return Scaffold(
            appBar: AppBar(
              title: const Text('نقطة البيع السريع'),
              actions: [
                IconButton(
                  icon: Icon(
                    isWholesale ? Icons.store : Icons.storefront,
                    color: isWholesale ? Colors.green : null,
                  ),
                  tooltip: isWholesale ? 'وضع التجزئة' : 'وضع الجملة',
                  onPressed: () {
                    if (state is PosLoaded) {
                      context.read<PosBloc>().add(
                            ToggleWholesaleMode(!state.isWholesaleMode),
                          );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () => context.push('/sales'),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () => _openScanner(context),
                ),
              ],
            ),
            body: state is PosLoading
                ? const Center(child: CircularProgressIndicator())
                : state is PosLoaded
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 800;
                          final isTablet = constraints.maxWidth > 500 && constraints.maxWidth <= 800;
                          
                          if (isWide) {
                            return Row(
                              children: [
                                const Expanded(flex: 2, child: CartWidget()),
                                Expanded(
                                  flex: 3,
                                  child: _buildProductSection(),
                                ),
                              ],
                            );
                          } else if (isTablet) {
                            return Row(
                              children: [
                                const Expanded(flex: 1, child: CartWidget()),
                                Expanded(
                                  flex: 2,
                                  child: _buildProductSection(),
                                ),
                              ],
                            );
                          }
                          return DefaultTabController(
                            length: 2,
                            child: Column(
                              children: [
                                const TabBar(
                                  tabs: [Tab(text: 'المنتجات'), Tab(text: 'السلة')],
                                ),
                                Expanded(
                                  child: TabBarView(
                                    children: [
                                      _buildProductSection(),
                                      const CartWidget(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : const Center(child: Text('بدء نقطة البيع...')),
          );
        },
      ),
    );
  }

  Widget _buildProductSection() {
    return Column(
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
    QuickCustomerService quickCustomerService,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تمت عملية البيع بنجاح'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );

    context.read<PosBloc>().add(ClearCart());

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    String customerName = 'عميل نقدي';
    String? customerPhone;

    if (state.sale.customerId != null) {
      final customer = await sl<AppDatabase>()
          .customersDao
          .getCustomerById(state.sale.customerId!);
      if (customer != null) {
        customerName = customer.name;
        customerPhone = customer.phone;
      }
    } else {
      final quickCustomer = await quickCustomerService.getOrCreateCustomerForSale('عميل نقدي');
      if (quickCustomer != null) {
        customerName = quickCustomer.name;
        customerPhone = quickCustomer.phone;
      }
    }

    final hasCustomerPhone = customerPhone != null && customerPhone.isNotEmpty;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('🧾 الفاتورة #${state.sale.id.substring(0, 8)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الإجمالي: ${state.sale.total.toStringAsFixed(2)} ر.س'),
            const SizedBox(height: 16),
            const Text('كيف تريد إرسال الفاتورة؟'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقاً'),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.print),
            tooltip: 'طباعة',
            onPressed: () async {
              Navigator.pop(ctx);
              await PrinterHelper.printReceipt(
                state.sale,
                state.items,
                state.products,
                customerName: customerName,
              );
            },
          ),
          if (hasCustomerPhone)
            IconButton.filledTonal(
              icon: const Icon(Icons.message, color: Colors.green),
              tooltip: 'WhatsApp',
              onPressed: () async {
                Navigator.pop(ctx);
                await commService.sendInvoiceViaWhatsApp(
                  phoneNumber: customerPhone!,
                  invoiceNumber: state.sale.id.substring(0, 8),
                  total: state.sale.total,
                  customerName: customerName,
                );
              },
            ),
          IconButton.filledTonal(
            icon: const Icon(Icons.share),
            tooltip: 'مشاركة',
            onPressed: () {
              Navigator.pop(ctx);
              final String shareText = 'فاتورة من نظام السوبر ماركت\n'
                  'رقم الفاتورة: #${state.sale.id.substring(0, 8)}\n'
                  'العميل: $customerName\n'
                  'الإجمالي: ${state.sale.total.toStringAsFixed(2)} ر.س\n'
                  'شكراً لتسوقكم معنا!';
              Share.share(shareText);
            },
          ),
        ],
      ),
    );
  }
}
