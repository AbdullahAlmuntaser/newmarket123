import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class CustomerTrailingWidgets extends StatelessWidget {
  final Customer customer;
  final AppDatabase db;
  final AppLocalizations l10n;
  final Function(AppDatabase, Customer) onPayAmount;

  const CustomerTrailingWidgets({
    super.key,
    required this.customer,
    required this.db,
    required this.l10n,
    required this.onPayAmount,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l10n.balanceLabel(customer.balance.toStringAsFixed(2)),
              style: TextStyle(
                color: customer.balance > 0 ? colorScheme.error : colorScheme.tertiary, // Themed colors
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              l10n.limitLabel(customer.creditLimit.toStringAsFixed(2)),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.payment),
          color: colorScheme.primary, // Themed color
          tooltip: l10n.payAmount,
          onPressed: () => onPayAmount(db, customer),
        ),
        IconButton(
          icon: const Icon(Icons.receipt_long),
          color: colorScheme.secondary, // Themed color
          tooltip: l10n.customerStatementTooltip,
          onPressed: () => context.push('/customers/statement/${customer.id}'),
        ),
      ],
    );
  }
}
