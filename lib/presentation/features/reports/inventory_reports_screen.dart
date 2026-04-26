import 'package:flutter/material.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/presentation/features/reports/widgets/inventory_value_report.dart';
import 'package:supermarket/presentation/features/reports/widgets/low_stock_report.dart';
import 'package:supermarket/presentation/features/reports/widgets/inventory_transactions_report.dart';
import 'package:supermarket/presentation/features/reports/widgets/product_batches_report.dart';

class InventoryReportsScreen extends StatelessWidget {
  const InventoryReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inventoryReports)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          InventoryValueReport(),
          SizedBox(height: 24),
          LowStockReport(),
          SizedBox(height: 24),
          InventoryTransactionsReportWidget(),
          SizedBox(height: 24),
          ProductBatchesReportWidget(),
        ],
      ),
    );
  }
}
