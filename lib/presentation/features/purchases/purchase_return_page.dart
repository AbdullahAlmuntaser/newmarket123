import 'package:flutter/material.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class PurchaseReturnPage extends StatelessWidget {
  const PurchaseReturnPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.purchaseReturns)),
      body: Center(
        child: Text(l10n.noReturnsYet),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/purchases/returns/new');
        },
        tooltip: l10n.newPurchaseReturn,
        child: const Icon(Icons.add),
      ),
    );
  }
}
