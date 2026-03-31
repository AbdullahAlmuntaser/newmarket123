import 'package:flutter/material.dart' hide Column;
import 'package:flutter/material.dart' as flutter show Column;
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/core/auth/auth_provider.dart';

class ShiftsPage extends StatefulWidget {
  const ShiftsPage({super.key});

  @override
  State<ShiftsPage> createState() => _ShiftsPageState();
}

class _ShiftsPageState extends State<ShiftsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = context.read<AppDatabase>();
    final auth = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.shiftManagement)),
      body: StreamBuilder<Shift?>(
        stream:
            (db.select(db.shifts)..where(
                  (t) =>
                      t.isOpen.equals(true) &
                      t.userId.equals(auth.currentUser!.id),
                ))
                .watchSingleOrNull(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final currentShift = snapshot.data;

          if (currentShift == null) {
            return _buildOpenShiftView(context, l10n);
          }

          return _buildCloseShiftView(context, l10n, currentShift);
        },
      ),
    );
  }

  Widget _buildOpenShiftView(BuildContext context, AppLocalizations l10n) {
    final db = context.read<AppDatabase>();
    final auth = context.read<AuthProvider>();
    final amountController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: flutter.Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_open, size: 80, color: Colors.green),
          const SizedBox(height: 24),
          Text(l10n.noOpenShift, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 32),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.openingCash,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.money),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0.0;
                await db
                    .into(db.shifts)
                    .insert(
                      ShiftsCompanion.insert(
                        userId: auth.currentUser!.id,
                        openingCash: Value(amount),
                        isOpen: const Value(true),
                      ),
                    );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(l10n.openShift),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseShiftView(
    BuildContext context,
    AppLocalizations l10n,
    Shift shift,
  ) {
    final db = context.read<AppDatabase>();
    final closingAmountController = TextEditingController();

    return FutureBuilder<double>(
      future: _calculateExpectedCash(db, shift),
      builder: (context, snapshot) {
        final double salesAmount = snapshot.data == null ? 0.0 : snapshot.data!;
        final double expected = salesAmount + shift.openingCash;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: flutter.Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: flutter.Column(
                    children: [
                      Text(
                        l10n.currentShift,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        l10n.dateLabel(
                          DateFormat(
                            'yyyy-MM-dd HH:mm',
                          ).format(shift.startTime),
                        ),
                        "",
                      ),
                      _buildInfoRow(
                        l10n.openingCash,
                        shift.openingCash.toStringAsFixed(2),
                      ),
                      _buildInfoRow(
                        l10n.expectedCash,
                        expected.toStringAsFixed(2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: closingAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.closingCash,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final actual =
                      double.tryParse(closingAmountController.text) ?? 0.0;
                  await (db.update(
                    db.shifts,
                  )..where((t) => t.id.equals(shift.id))).write(
                    ShiftsCompanion(
                      endTime: Value(DateTime.now()),
                      closingCash: Value(actual),
                      expectedCash: Value(expected),
                      isOpen: const Value(false),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(l10n.closeShift),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<double> _calculateExpectedCash(AppDatabase db, Shift shift) async {
    // Only count cash sales since shift start
    final query = db.select(db.sales)
      ..where(
        (t) =>
            t.createdAt.isBiggerOrEqualValue(shift.startTime) &
            t.paymentMethod.equals('cash'),
      );
    final result = await query.get();

    return result.fold<double>(0.0, (prev, sale) => prev + sale.total);
  }
}
