import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class BalanceSheetPage extends StatelessWidget {
  const BalanceSheetPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AccountingProvider>();

    return Scaffold(
      body: FutureBuilder<BalanceSheetData>(
        future: provider.getBalanceSheet(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null) return const Center(child: Text('No data'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(l10n.assets),
                ...data.assets.map(
                  (item) => _buildAccountRow(item.account.name, item.balance),
                ),
                const Divider(thickness: 2),
                _buildTotalRow(l10n.totalAssets, data.totalAssets),
                const SizedBox(height: 24),
                _buildSectionHeader(l10n.liabilities),
                ...data.liabilities.map(
                  (item) => _buildAccountRow(item.account.name, item.balance),
                ),
                const Divider(thickness: 2),
                _buildTotalRow(l10n.totalLiabilities, data.totalLiabilities),
                const SizedBox(height: 24),
                _buildSectionHeader(l10n.equity),
                ...data.equity.map(
                  (item) => _buildAccountRow(item.account.name, item.balance),
                ),
                _buildAccountRow(l10n.netIncome, data.netIncome),
                const Divider(thickness: 2),
                _buildTotalRow(l10n.totalEquity, data.totalEquity),
                const SizedBox(height: 32),
                _buildBalanceCheck(data, l10n),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildAccountRow(String name, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(name), Text(amount.toStringAsFixed(2))],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          amount.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBalanceCheck(BalanceSheetData data, AppLocalizations l10n) {
    final isBalanced =
        (data.totalAssets - (data.totalLiabilities + data.totalEquity)).abs() <
        0.01;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBalanced
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        border: Border.all(color: isBalanced ? Colors.green : Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          isBalanced ? l10n.balanceSheetBalanced : l10n.balanceSheetNotBalanced,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isBalanced ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }
}
