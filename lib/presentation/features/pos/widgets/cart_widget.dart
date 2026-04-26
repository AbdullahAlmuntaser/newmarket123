import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_state.dart';
import 'package:supermarket/presentation/features/pos/widgets/add_unit_dialog.dart';
import 'package:supermarket/presentation/features/pos/widgets/checkout_dialog.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:decimal/decimal.dart';

class CartWidget extends StatelessWidget {
  const CartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BlocBuilder<PosBloc, PosState>(
          builder: (context, state) {
            if (state is! PosLoaded) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.cart,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (state.isWholesaleMode)
                      const Chip(
                        label: Text('وضع الجملة نشط'),
                        backgroundColor: Colors.blue,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: state.cart.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'السلة فارغة',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: state.cart.length,
                          itemBuilder: (context, index) {
                            final item = state.cart[index];
                            return _buildCartItem(context, item);
                          },
                        ),
                ),
                const Divider(height: 24),
                _buildSummary(context, state, l10n),
                const SizedBox(height: 16),
                _buildCheckoutButton(context, state, l10n),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item) {
    return Dismissible(
      key: Key(item.product.id + item.unitName),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        context.read<PosBloc>().add(RemoveCartItem(item.product.id));
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => _showUnitSelection(context, item),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blue),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.unitName,
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (item.unitFactor > Decimal.one)
                              Text(
                                'يعادل: ${item.unitFactor} ${item.product.unit}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.total.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _qtyBtn(Icons.remove, () {
                        if (item.quantity > Decimal.one) {
                          context.read<PosBloc>().add(
                            UpdateCartItemQuantity(
                              item.product.id,
                              item.quantity - Decimal.one,
                            ),
                          );
                        }
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          item.quantity.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _qtyBtn(Icons.add, () {
                        context.read<PosBloc>().add(
                          UpdateCartItemQuantity(
                            item.product.id,
                            item.quantity + Decimal.one,
                          ),
                        );
                      }),
                    ],
                  ),
                  Text(
                    'سعر الوحدة: ${item.unitPrice.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[200],
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _buildSummary(
    BuildContext context,
    PosLoaded state,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        _summaryRow(l10n.subtotal, state.subtotal.toStringAsFixed(2)),
        if (state.discount > Decimal.zero)
          _summaryRow(
            l10n.discount,
            '-${state.discount.toStringAsFixed(2)}',
            color: Colors.red,
          ),
        _summaryRow(l10n.tax, state.taxAmount.toStringAsFixed(2)),
        const Divider(),
        _summaryRow(
          l10n.total,
          state.total.toStringAsFixed(2),
          isBold: true,
          fontSize: 22,
          color: Colors.blue[900],
        ),
      ],
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 14,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(
    BuildContext context,
    PosLoaded state,
    AppLocalizations l10n,
  ) {
    return ElevatedButton(
      onPressed: state.cart.isEmpty ? null : () => _handleCheckout(context),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        l10n.checkout,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showUnitSelection(BuildContext context, CartItem item) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('اختيار وحدة لـ ${item.product.name}'),
            trailing: TextButton.icon(
              onPressed: () => _quickAddUnit(context, item),
              icon: const Icon(Icons.add),
              label: const Text('إضافة وحدة'),
            ),
          ),
          const Divider(),
          // Base Unit
          ListTile(
            title: Text(item.product.unit),
            subtitle: const Text('الوحدة الأساسية'),
            trailing: item.unitName == item.product.unit
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () {
              context.read<PosBloc>().add(
                UpdateCartItemUnit(item.product.id, item.product.unit),
              );
              Navigator.pop(ctx);
            },
          ),
          // Other Units
          ...item.availableUnits.map(
            (u) => ListTile(
              title: Text(u.unitName),
              subtitle: Text('المعامل: ${u.factor}'),
              trailing: item.unitName == u.unitName
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                context.read<PosBloc>().add(
                  UpdateCartItemUnit(item.product.id, u.unitName),
                );
                Navigator.pop(ctx);
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _quickAddUnit(BuildContext context, CartItem item) async {
    final database = context.read<AppDatabase>();
    final posBloc = context.read<PosBloc>();
    Navigator.pop(context); // Close bottom sheet
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddUnitDialog(
        productId: item.product.id,
        productName: item.product.name,
      ),
    );

    if (result != null) {
      await database
          .into(database.unitConversions)
          .insert(
            UnitConversionsCompanion.insert(
              productId: item.product.id,
              unitName: result['unitName'],
              factor: result['factor'],
              barcode: drift.Value(result['barcode']),
              sellPrice: drift.Value(result['sellPrice']),
            ),
          );
      // Reload units in Bloc
      posBloc.add(UpdateCartItemUnit(item.product.id, result['unitName']));
    }
  }

  void _handleCheckout(BuildContext context) {
    final posBloc = context.read<PosBloc>();
    final state = posBloc.state;
    if (state is! PosLoaded) return;

    showDialog(
      context: context,
      builder: (context) => BlocProvider.value(
        value: posBloc,
        child: CheckoutDialog(state: state),
      ),
    );
  }
}
