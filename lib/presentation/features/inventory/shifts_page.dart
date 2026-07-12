import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:supermarket/core/constants/app_enums.dart';

class InventoryShiftsPage extends StatelessWidget {
  const InventoryShiftsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير تسليم الورديات')),
      body: StreamBuilder<List<Shift>>(
        stream: db.select(db.shifts).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final shifts = snapshot.data!;
          if (shifts.isEmpty) {
            return const Center(child: Text('لا توجد ورديات بعد'));
          }
          return ListView.builder(
            itemCount: shifts.length,
            itemBuilder: (context, index) {
              final shift = shifts[index];
              return _ShiftCard(shift: shift, db: db);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openShift(context, db),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openShift(BuildContext context, AppDatabase db) async {
    await db.into(db.shifts).insert(ShiftsCompanion.insert(
          userId: 'current_user_id',
          startTime: drift.Value(DateTime.now()),
          isOpen: const drift.Value(true),
        ));
  }
}

class _ShiftCard extends StatelessWidget {
  final Shift shift;
  final AppDatabase db;

  const _ShiftCard({required this.shift, required this.db});

  String _formatTime(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm').format(dt);

  String _formatDuration(DateTime start, DateTime? end) {
    final e = end ?? DateTime.now();
    final diff = e.difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return '${h}s ${m}d';
  }

  Future<Map<String, dynamic>> _getShiftSummary() async {
    final startTime = shift.startTime;
    final endTime = shift.endTime ?? DateTime.now();

    final sales = await (db.select(db.sales)
          ..where((s) => s.createdAt.isBetweenValues(startTime, endTime))
          ..where((s) => s.status.equals(DocumentStatus.posted.index)))
        .get();

    final totalSales =
        sales.fold<Decimal>(Decimal.zero, (sum, s) => sum + s.total);
    final cashSales = sales
        .where((s) => s.paymentMethod == PaymentMethod.cash)
        .fold<Decimal>(Decimal.zero, (sum, s) => sum + s.total);
    final bankSales = sales
        .where((s) => s.paymentMethod == PaymentMethod.bank)
        .fold<Decimal>(Decimal.zero, (sum, s) => sum + s.total);

    return {
      'salesCount': sales.length,
      'totalSales': totalSales,
      'cashTotal': cashSales,
      'bankTotal': bankSales,
    };
  }

  void _showReport(BuildContext context) async {
    final summary = await _getShiftSummary();
    if (!context.mounted) return;

    final salesCount = summary['salesCount'] as int;
    final totalSales = summary['totalSales'] as Decimal;
    final cashTotal = summary['cashTotal'] as Decimal;
    final bankTotal = summary['bankTotal'] as Decimal;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تقرير الوردية'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _infoRow('بداية الوردية', _formatTime(shift.startTime)),
              if (shift.endTime != null)
                _infoRow('نهاية الوردية', _formatTime(shift.endTime!)),
              _infoRow(
                  'المدة', _formatDuration(shift.startTime, shift.endTime)),
              _infoRow('رقم المستخدم', shift.userId),
              const Divider(),
              _infoRow('رصيد البداية', '${shift.openingCash} ر.س'),
              if (shift.expectedCash != null)
                _infoRow('الرصيد المتوقع', '${shift.expectedCash} ر.س'),
              if (shift.closingCash != null)
                _infoRow('رصيد النهاية', '${shift.closingCash} ر.س'),
              if (shift.expectedCash != null && shift.closingCash != null) ...[
                _infoRow(
                    'الفرق', '${shift.closingCash! - shift.expectedCash!} ر.س'),
              ],
              const Divider(),
              _infoRow('عدد الفواتير', '$salesCount'),
              _infoRow('إجمالي المبيعات', '$totalSales ر.س'),
              _infoRow('نقداً', '$cashTotal ر.س'),
              _infoRow('بطاقة', '$bankTotal ر.س'),
              if (shift.note != null && shift.note!.isNotEmpty) ...[
                const Divider(),
                Text('ملاحظات: ${shift.note}',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = shift.isOpen;
    final duration = _formatDuration(shift.startTime, shift.endTime);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOpen ? Icons.play_circle : Icons.check_circle,
                  color: isOpen ? Colors.green : Colors.blueGrey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_formatTime(shift.startTime)}  -  $duration',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        isOpen ? Colors.green.shade50 : Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOpen ? 'مفتوحة' : 'مغلقة',
                    style: TextStyle(
                      color: isOpen ? Colors.green : Colors.blueGrey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'المستخدم: ${shift.userId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'رصيد البداية: ${shift.openingCash} ر.س'
              '${shift.closingCash != null ? '  |  رصيد النهاية: ${shift.closingCash} ر.س' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (shift.note != null && shift.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'ملاحظة: ${shift.note}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                ),
              ),
            if (!isOpen)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showReport(context),
                    icon: const Icon(Icons.assessment, size: 18),
                    label: const Text('عرض التقرير'),
                  ),
                ),
              ),
            if (isOpen)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await (db.update(db.shifts)
                            ..where((s) => s.id.equals(shift.id)))
                          .write(
                        ShiftsCompanion(
                          endTime: drift.Value(DateTime.now()),
                          isOpen: const drift.Value(false),
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock, size: 18),
                    label: const Text('إغلاق الوردية'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
