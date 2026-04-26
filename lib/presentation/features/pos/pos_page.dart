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
    return BlocListener<PosBloc, PosState>(
      listener: (context, state) {
        if (state is PosCheckoutSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تمت عملية البيع بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          // Clear cart and reset to PosLoaded
          context.read<PosBloc>().add(ClearCart());
        } else if (state is PosError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نقطة البيع السريع'),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => context.push('/sales'),
              tooltip: 'سجل المبيعات',
            ),
            BlocBuilder<PosBloc, PosState>(
              builder: (context, state) {
                if (state is! PosLoaded) return const SizedBox.shrink();
                return Row(
                  children: [
                    const Text('جملة'),
                    Switch(
                      value: state.isWholesaleMode,
                      onChanged: (value) {
                        context.read<PosBloc>().add(ToggleWholesaleMode(value));
                      },
                    ),
                  ],
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => _openScanner(context),
            ),
          ],
        ),
        body: Row(
          children: [
            // Left Side: Cart & Checkout
            const Expanded(flex: 2, child: CartWidget()),
            // Right Side: Products & Search
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
}
