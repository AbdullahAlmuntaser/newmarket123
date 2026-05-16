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
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    return Card(
      margin: EdgeInsets.all(isCompact ? 4.0 : 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 8.0 : 16.0),
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
                    Flexible(
                      child: Text(
                        l10n.cart,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (state.isWholesaleMode)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'جملة',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 16),
                Expanded(
                  child: state.cart.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: isCompact ? 48 : 64,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'السلة فارغة',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: state.cart.length,
                          itemBuilder: (context, index) {
                            final item = state.cart[index];
                            return _buildCartItem(context, item, isCompact);
                          },
                        ),
                ),
                const Divider(height: 16),
                _buildSummary(context, state, l10n, isCompact),
                const SizedBox(height: 12),
                _buildCheckoutButton(context, state, l10n, isCompact),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item, bool isCompact) {
    return Dismissible(
      key: Key(item.product.id + item.unitName),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: Icon(
          Icons.delete,
          color: Theme.of(context).colorScheme.onError,
        ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.unitName,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!isCompact) ...[
                              const SizedBox(width: 8),
                              if (item.unitFactor > Decimal.one)
                                Flexible(
                                  child: Text(
                                    '${item.unitFactor} ${item.product.unit}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.total.toStringAsFixed(2),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
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
                  if (!isCompact)
                    Text(
                      '${item.unitPrice.toStringAsFixed(2)} / وحدة',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline,
                      ),
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
    bool isCompact,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _summaryRow(
          l10n.subtotal,
          state.subtotal.toStringAsFixed(2),
          theme: theme,
        ),
        if (state.discount > Decimal.zero)
          _summaryRow(
            l10n.discount,
            '-${state.discount.toStringAsFixed(2)}',
            color: theme.colorScheme.error,
            theme: theme,
          ),
        _summaryRow(l10n.tax, state.taxAmount.toStringAsFixed(2), theme: theme),
        const Divider(),
        _summaryRow(
          l10n.total,
          state.total.toStringAsFixed(2),
          isBold: true,
          fontSize: isCompact ? 18 : 22,
          color: theme.colorScheme.primary,
          theme: theme,
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
    required ThemeData theme,
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
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? theme.colorScheme.onSurface,
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
    bool isCompact,
  ) {
    final isProcessing = state.isProcessingCheckout;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: state.cart.isEmpty || isProcessing ? null : () => _handleCheckout(context),
        icon: isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.shopping_cart_checkout),
        label: Text(
          isProcessing ? 'جاري...' : l10n.checkout,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
      await database.into(database.unitConversions).insert(
            UnitConversionsCompanion.insert(
              productId: item.product.id,
              unitName: result['unitName'] as String,
              factor: result['factor'] as double,
              barcode: drift.Value(result['barcode'] as String?),
              sellPrice: drift.Value(result['sellPrice'] as double?),
            ),
          );
      // Reload units in Bloc
      posBloc.add(UpdateCartItemUnit(item.product.id, result['unitName'] as String));
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
