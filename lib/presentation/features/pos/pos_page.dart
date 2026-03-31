import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/invoice_service.dart';
import 'package:supermarket/core/utils/printer_helper.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_state.dart';
import 'package:supermarket/presentation/features/pos/widgets/product_grid.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';

class PosPage extends StatelessWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pos),
        actions: [
          BlocBuilder<PosBloc, PosState>(
            builder: (context, state) {
              final isWholesale = state is PosLoaded ? state.isWholesaleMode : false;
              return Row(
                children: [
                  Text(l10n.wholesale),
                  Switch(
                    value: isWholesale,
                    onChanged: (val) => context.read<PosBloc>().add(ToggleWholesaleMode(val)),
                  ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => context.read<PosBloc>().add(ClearCart()),
            tooltip: l10n.clearCart,
          ),
        ],
      ),
      drawer: const MainDrawer(),
      body: Row(
        children: [
          const Expanded(flex: 2, child: ProductGrid()),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: BlocConsumer<PosBloc, PosState>(
                    listener: (context, state) {
                      if (state is PosError) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
                      }
                      if (state is PosCheckoutSuccess) {
                        _showPrintDialog(context, state);
                      }
                    },
                    builder: (context, state) {
                      if (state is PosLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is PosLoaded) {
                        if (state.cart.isEmpty) {
                          return Center(child: Text(l10n.cartEmpty));
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: state.cart.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = state.cart[index];
                            return ListTile(
                              title: Text(item.product.name),
                              subtitle: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => context.read<PosBloc>().add(
                                          UpdateCartItemQuantity(
                                            item.product.id,
                                            item.quantity - 1,
                                          ),
                                        ),
                                  ),
                                  Text('${item.quantity}'),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => context.read<PosBloc>().add(
                                          UpdateCartItemQuantity(
                                            item.product.id,
                                            item.quantity + 1,
                                          ),
                                        ),
                                  ),
                                  Text(' x ${item.unitPrice}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${item.total}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () => context.read<PosBloc>().add(RemoveCartItem(item.product.id)),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                _buildAdvancedSummary(context, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSummary(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BlocBuilder<PosBloc, PosState>(
        builder: (context, state) {
          if (state is! PosLoaded) return const SizedBox.shrink();

          return Column(
            children: [
              _buildSummaryRow(l10n.subtotal, '${state.subtotal}'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.discount),
                  SizedBox(
                    width: 100,
                    height: 35,
                    child: TextField(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => context.read<PosBloc>().add(
                            UpdateDiscount(double.tryParse(val) ?? 0),
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(l10n.tax, state.taxAmount.toStringAsFixed(2)),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.total,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    state.total.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.cart.isEmpty ? null : () => _showCheckoutDialog(context, l10n),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: Text(l10n.proceedToCheckout),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showCheckoutDialog(BuildContext context, AppLocalizations l10n) {
    final db = context.read<AppDatabase>();
    Customer? selectedCustomer;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.completePayment),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<List<Customer>>(
                stream: db.select(db.customers).watch(),
                builder: (context, snapshot) {
                  final customers = snapshot.data ?? [];
                  return DropdownButtonFormField<Customer>(
                    decoration: InputDecoration(labelText: l10n.selectCustomer),
                    items: customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                    onChanged: (val) => setState(() => selectedCustomer = val),
                  );
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.money, color: Colors.green),
                title: Text(l10n.cashPayment),
                onTap: () {
                  context.read<PosBloc>().add(CheckoutEvent('cash', customerId: selectedCustomer?.id));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.credit_card, color: Colors.blue),
                title: Text(l10n.creditSale),
                onTap: () {
                  if (selectedCustomer == null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.selectCustomerError)));
                    return;
                  }
                  context.read<PosBloc>().add(CheckoutEvent('credit', customerId: selectedCustomer?.id));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrintDialog(BuildContext context, PosCheckoutSuccess state) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.saveSuccess),
        content: Text(l10n.accountingSystem),
        actions: [
          TextButton(
            onPressed: () {
              context.read<PosBloc>().add(ClearCart());
              Navigator.pop(context);
            },
            child: Text(l10n.cancel),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.print),
            onPressed: () async {
              try {
                final isConnected = await PrinterHelper.isConnected();
                if (isConnected) {
                  await PrinterHelper.printReceipt(state.sale, state.items, state.products);
                } else {
                  final bytes = await PrinterHelper.generateSaleReceipt(state.sale, state.items, state.products);
                  debugPrint("Generated ${bytes.length} bytes for receipt (offline)");
                }
              } catch (e) {
                debugPrint("Printing error: $e");
              }
              if (context.mounted) {
                context.read<PosBloc>().add(ClearCart());
                Navigator.pop(context);
              }
            },
            label: Text(l10n.printReceipt),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Print Invoice'),
            onPressed: () async {
              try {
                final itemsWithProduct = state.items.map((item) {
                  final product = state.products.firstWhere((p) => p.id == item.productId);
                  return SaleItemWithProduct(
                    product: product,
                    quantity: item.quantity,
                    price: item.price,
                  );
                }).toList();
                final file = await InvoiceService.generateInvoice(
                  context,
                  sale: state.sale,
                  items: itemsWithProduct,
                  companyName: 'My Supermarket',
                  vatNumber: '1234567890',
                );
                await Printing.layoutPdf(onLayout: (format) => file.readAsBytes());
              } catch (e) {
                debugPrint("Invoice generation error: $e");
              }
              if (context.mounted) {
                context.read<PosBloc>().add(ClearCart());
                Navigator.pop(context);
              }
            },
          )
        ],
      ),
    );
  }
}
