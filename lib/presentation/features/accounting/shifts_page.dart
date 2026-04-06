import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/presentation/features/accounting/shifts_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/core/auth/auth_provider.dart';

class ShiftsPage extends StatefulWidget {
  const ShiftsPage({super.key});

  @override
  State<ShiftsPage> createState() => _ShiftsPageState();
}

class _ShiftsPageState extends State<ShiftsPage> {
  final _cashController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().currentUser?.id;
      if (userId != null) {
        context.read<ShiftProvider>().checkActiveShift(userId);
      }
    });
  }

  @override
  void dispose() {
    _cashController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shiftProvider = context.watch<ShiftProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.shiftManagement)),
      body: shiftProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: shiftProvider.hasActiveShift
                  ? _buildActiveShiftView(l10n, shiftProvider.activeShift!)
                  : _buildOpenShiftView(l10n, authProvider.currentUser?.id),
            ),
    );
  }

  Widget _buildActiveShiftView(AppLocalizations l10n, dynamic shift) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(l10n.currentShift, style: Theme.of(context).textTheme.headlineSmall),
                const Divider(),
                _infoRow(l10n.openShift, DateFormat('yyyy-MM-dd HH:mm').format(shift.startTime)),
                _infoRow(l10n.openingCash, shift.openingCash.toStringAsFixed(2)),
              ],
            ),
          ),
        ),
        const Spacer(),
        TextField(
          controller: _cashController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.closingCash,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.money),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _noteController,
          decoration: InputDecoration(
            labelText: l10n.notes,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.note),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => _handleCloseShift(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(l10n.closeShift, style: const TextStyle(fontSize: 18)),
        ),
      ],
    );
  }

  Widget _buildOpenShiftView(AppLocalizations l10n, String? userId) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_open, size: 100, color: Theme.of(context).primaryColor.withValues(alpha: 0.2)),
        const SizedBox(height: 24),
        Text(l10n.noOpenShift, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 32),
        TextField(
          controller: _cashController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.openingCash,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.money),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _noteController,
          decoration: InputDecoration(
            labelText: l10n.notes,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.note),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: userId == null ? null : () => _handleOpenShift(context, userId),
            child: Text(l10n.openShift, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Future<void> _handleOpenShift(BuildContext context, String userId) async {
    final cash = double.tryParse(_cashController.text);
    if (cash == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid cash amount')));
      return;
    }

    try {
      await context.read<ShiftProvider>().openShift(userId, cash, note: _noteController.text);
      if (!context.mounted) return;
      _cashController.clear();
      _noteController.clear();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _handleCloseShift(BuildContext context) async {
    final cash = double.tryParse(_cashController.text);
    if (cash == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid cash amount')));
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final shiftProvider = context.read<ShiftProvider>();
    final expectedCash = await shiftProvider.getExpectedCash();
    final diff = cash - expectedCash;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.closeShift),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow(l10n.expectedCash, expectedCash.toStringAsFixed(2)),
            _infoRow(l10n.closingCash, cash.toStringAsFixed(2)),
            _infoRow(l10n.difference, diff.toStringAsFixed(2)),
            if (diff != 0)
              Text(
                diff > 0 ? 'Cash Surplus' : 'Cash Shortage',
                style: TextStyle(color: diff > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await shiftProvider.closeShift(cash, note: _noteController.text);
              navigator.pop();
              _cashController.clear();
              _noteController.clear();
            },
            child: Text(l10n.closeShift),
          ),
        ],
      ),
    );
  }
}
