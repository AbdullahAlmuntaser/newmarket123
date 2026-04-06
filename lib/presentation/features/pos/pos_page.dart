import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/services/invoice_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/utils/printer_helper.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_state.dart';
import 'package:supermarket/presentation/features/pos/widgets/product_grid.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

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
      body: Column(
        children: [
          _buildTopSearchBar(context, l10n),
          _buildCategorySelector(),
          Expanded(
            child: Row(
              children: [
                const Expanded(flex: 2, child: ProductGrid()),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 1,
                  child: _buildCartSection(context, l10n),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        if (state is! PosLoaded) return const SizedBox.shrink();

        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(0x4D),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: state.categories.length + 1,
            itemBuilder: (context, index) {
              final isAll = index == 0;
              final category = isAll ? null : state.categories[index - 1];
              final isSelected = isAll 
                  ? state.selectedCategoryId == null 
                  : state.selectedCategoryId == category?.id;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(isAll ? "الكل" : category!.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      context.read<PosBloc>().add(SelectCategory(category?.id));
                    }
                  },
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTopSearchBar(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Expanded(
            child: SearchAnchor(
              builder: (context, controller) {
                return SearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  hintText: 'ابحث بالاسم أو الباركود...',
                  onChanged: (val) {
                    context.read<PosBloc>().add(SearchProducts(val));
                  },
                  onSubmitted: (val) {
                    if (val.isNotEmpty) {
                      context.read<PosBloc>().add(AddProductBySku(val));
                      _searchController.clear();
                      _searchFocusNode.requestFocus();
                    }
                  },
                  leading: const Icon(Icons.search),
                  trailing: [
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () {
                        // هنا يمكن إضافة فتح الكاميرا للمسح
                      },
                    ),
                  ],
                );
              },
              suggestionsBuilder: (context, controller) {
                final state = context.read<PosBloc>().state;
                if (state is PosLoaded) {
                  return state.searchResults.map((product) => ListTile(
                        title: Text(product.name),
                        subtitle: Text('SKU: ${product.sku} | السعر: ${product.sellPrice}'),
                        onTap: () {
                          context.read<PosBloc>().add(AddProductBySku(product.sku));
                          _searchController.clear();
                          _searchFocusNode.requestFocus();
                        },
                      ));
                }
                return [];
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSection(BuildContext context, AppLocalizations l10n) {
    return Column(
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Row(
                        children: [
                          _quantityButton(
                            Icons.remove,
                            () => context.read<PosBloc>().add(UpdateCartItemQuantity(item.product.id, item.quantity - 1)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('${item.quantity}', style: const TextStyle(fontSize: 16)),
                          ),
                          _quantityButton(
                            Icons.add,
                            () => context.read<PosBloc>().add(UpdateCartItemQuantity(item.product.id, item.quantity + 1)),
                          ),
                          const Spacer(),
                          Text('${item.unitPrice} x'),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(item.total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          InkWell(
                            onTap: () => context.read<PosBloc>().add(RemoveCartItem(item.product.id)),
                            child: const Text('حذف', style: TextStyle(color: Colors.red, fontSize: 12)),
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
    );
  }

  Widget _quantityButton(IconData icon, VoidCallback onTap) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18),
        onPressed: onTap,
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
            color: Colors.black.withAlpha(13),
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
              _buildSummaryRow(l10n.subtotal, state.subtotal.toStringAsFixed(2)),
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
                      onChanged: (val) => context.read<PosBloc>().add(UpdateDiscount(double.tryParse(val) ?? 0)),
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
                  Text(l10n.total, style: Theme.of(context).textTheme.titleLarge),
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
                height: 55,
                child: ElevatedButton(
                  onPressed: state.cart.isEmpty ? null : () => _showCheckoutDialog(context, l10n),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(l10n.proceedToCheckout, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;
    final posState = context.read<PosBloc>().state as PosLoaded;
    Customer? selectedCustomer;
    final TextEditingController customerNameController = TextEditingController();
    final TextEditingController customerPhoneController = TextEditingController();
    final TextEditingController amountPaidController = TextEditingController();
    double change = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.completePayment),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // حساب المتبقي
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المبلغ المطلوب:'),
                          Text(posState.total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountPaidController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ المدفوع',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.money),
                        ),
                        onChanged: (val) {
                          final paid = double.tryParse(val) ?? 0;
                          setState(() {
                            change = paid - posState.total;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المتبقي للعميل:'),
                          Text(change > 0 ? change.toStringAsFixed(2) : "0.00",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: change >= 0 ? Colors.green : Colors.red, fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<Customer>>(
                  stream: db.customersDao.watchAllCustomers(),
                  builder: (context, snapshot) {
                    final customers = snapshot.data ?? [];
                    return Autocomplete<Customer>(
                      displayStringForOption: (customer) => customer.name,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') return const Iterable<Customer>.empty();
                        return customers.where((c) => c.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (Customer selection) {
                        setState(() {
                          selectedCustomer = selection;
                          customerNameController.text = selection.name;
                          customerPhoneController.text = selection.phone ?? '';
                        });
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: l10n.selectCustomer,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  selectedCustomer = null;
                                  customerNameController.clear();
                                  customerPhoneController.clear();
                                  textEditingController.clear();
                                });
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.money, color: Colors.green),
                  title: Text(l10n.cashPayment),
                  onTap: () {
                    context.read<PosBloc>().add(CheckoutEvent('cash', customerId: selectedCustomer?.id, userId: userId));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.credit_card, color: Colors.blue),
                  title: Text(l10n.creditSale),
                  onTap: () async {
                    String? customerId = selectedCustomer?.id;
                    if (selectedCustomer == null && customerNameController.text.isNotEmpty) {
                      final newCustomer = await db.into(db.customers).insertReturning(
                            CustomersCompanion.insert(
                              name: customerNameController.text,
                              phone: Value(customerPhoneController.text.isEmpty ? null : customerPhoneController.text),
                              creditLimit: const Value(0.0),
                              balance: const Value(0.0),
                            ),
                          );
                      customerId = newCustomer.id;
                    }

                    if (customerId == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار عميل للبيع الآجل')));
                      }
                      return;
                    }
                    if (context.mounted) {
                      context.read<PosBloc>().add(CheckoutEvent('credit', customerId: customerId, userId: userId));
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
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
      builder: (ctx) => AlertDialog(
        title: Text(l10n.saveSuccess),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.whatWouldYouLikeToDo),
            const SizedBox(height: 20),
            // PDF Invoice Button
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(l10n.downloadPdfInvoice),
              onPressed: () async {
              final messenger = ScaffoldMessenger.of(ctx);
              try {
                final db = context.read<AppDatabase>();
                String? customerName;
                if (state.sale.customerId != null) {
                  final customer = await db.customersDao.getCustomerById(state.sale.customerId!);
                  customerName = customer?.name;
                }

                final invoiceService = InvoiceService();
                final Uint8List pdfData = await invoiceService.generatePdfInvoice(
                  sale: state.sale,
                  items: state.items,
                  products: state.products,
                  customerName: customerName,
                  companyName: 'My Supermarket Inc.',
                  companyAddress: '123 Business Avenue, Metro City',
                  companyVatNumber: 'VAT123456789',
                );

                await Printing.sharePdf(
                  bytes: pdfData,
                  filename: 'invoice_${state.sale.id.substring(0, 8)}.pdf',
                );

              } catch (e) {
                debugPrint("PDF Generation Error: $e");
                if (ctx.mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to generate PDF: $e')),
                  );
                }
              }
              },
              ),
              const SizedBox(height: 10),
              // Thermal Receipt Button
              ElevatedButton.icon(
              icon: const Icon(Icons.print_outlined),
              label: Text(l10n.printReceipt),
              onPressed: () async {
              final messenger = ScaffoldMessenger.of(ctx);
              try {
                final db = context.read<AppDatabase>();
                String? customerName;
                if (state.sale.customerId != null) {
                  final customer = await db.customersDao.getCustomerById(state.sale.customerId!);
                  customerName = customer?.name;
                }

                final List<int> receiptData = await PrinterHelper.generateSaleReceipt(
                  state.sale,
                  state.items,
                  state.products,
                  customerName: customerName,
                );

                // Use printing package for a print preview
                await Printing.layoutPdf(
                  onLayout: (format) async => Uint8List.fromList(receiptData),
                );

              } catch (e) {
                debugPrint("Printing error: $e");
                 if (ctx.mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to generate receipt: $e')),
                  );
                }
              }
              },

            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<PosBloc>().add(ClearCart());
              Navigator.pop(ctx); // Use ctx here
            },
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }
}
