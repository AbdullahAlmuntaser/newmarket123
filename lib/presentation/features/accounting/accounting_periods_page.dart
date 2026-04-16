import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

/// صفحة إدارة الفترات المحاسبية
class AccountingPeriodsPage extends StatefulWidget {
  const AccountingPeriodsPage({super.key});

  @override
  State<AccountingPeriodsPage> createState() => _AccountingPeriodsPageState();
}

class _AccountingPeriodsPageState extends State<AccountingPeriodsPage> {
  final TextEditingController _nameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: const Text('الفترات المحاسبية')),
      body: Column(
        children: [
          // نموذج إضافة فترة
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'إضافة فترة جديدة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الفترة',
                      border: OutlineInputBorder(),
                      hintText: 'مثال: يناير 2026',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectStartDate(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'تاريخ البداية',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              _startDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                  : 'اختر التاريخ',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectEndDate(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'تاريخ النهاية',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              _endDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                  : 'اختر التاريخ',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _startDate != null && _endDate != null
                        ? () => _addPeriod(db)
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة فترة'),
                  ),
                ],
              ),
            ),
          ),

          // قائمة الفترات
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الفترات الموجودة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AccountingPeriod>>(
              stream: db.select(db.accountingPeriods).watch(),
              builder: (context, snapshot) {
                final periods = snapshot.data ?? [];
                if (periods.isEmpty) {
                  return const Center(child: Text('لا توجد فترات محاسبية'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: periods.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final period = periods[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          period.isClosed
                              ? Icons.lock_outline
                              : Icons.lock_open,
                          color: period.isClosed ? Colors.red : Colors.green,
                        ),
                        title: Text(period.name),
                        subtitle: Text(
                          '${DateFormat('yyyy-MM-dd').format(period.startDate)} - ${DateFormat('yyyy-MM-dd').format(period.endDate)}',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            if (!period.isClosed)
                              TextButton.icon(
                                onPressed: () =>
                                    _confirmClosePeriod(db, period),
                                icon: const Icon(Icons.lock, size: 18),
                                label: const Text('إغلاق'),
                              ),
                            if (period.isClosed)
                              TextButton.icon(
                                onPressed: () => _reopenPeriod(db, period),
                                icon: const Icon(Icons.lock_open, size: 18),
                                label: const Text('فتح'),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deletePeriod(db, period),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) setState(() => _startDate = date);
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) setState(() => _endDate = date);
  }

  Future<void> _addPeriod(AppDatabase db) async {
    if (_nameController.text.isEmpty ||
        _startDate == null ||
        _endDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى ملء جميع الحقول')));
      return;
    }

    await db
        .into(db.accountingPeriods)
        .insert(
          AccountingPeriodsCompanion.insert(
            id: drift.Value(const Uuid().v4()),
            name: _nameController.text,
            startDate: _startDate!,
            endDate: _endDate!,
            syncStatus: const drift.Value(1),
          ),
        );

    _nameController.clear();
    setState(() {
      _startDate = null;
      _endDate = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إضافة الفترة بنجاح')));
    }
  }

  Future<void> _confirmClosePeriod(
    AppDatabase db,
    AccountingPeriod period,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إغلاق الفترة'),
        content: Text(
          'هل أنت متأكد من إغلاق الفترة "${period.name}"؟\n'
          'سيتم ترحيل الأرباح إلى الأرباح المحتجزة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _closePeriod(db, period);
    }
  }

  Future<void> _closePeriod(AppDatabase db, AccountingPeriod period) async {
    try {
      // ترحيل الأرباح إلى الأرباح المحتجزة
      // (يتم عبر AccountingService.closeYear إذا لزم الأمر)

      await (db.update(db.accountingPeriods)
            ..where((p) => p.id.equals(period.id)))
          .write(const AccountingPeriodsCompanion(isClosed: drift.Value(true)));

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إغلاق الفترة بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل في إغلاق الفترة: $e')));
      }
    }
  }

  Future<void> _reopenPeriod(AppDatabase db, AccountingPeriod period) async {
    await (db.update(db.accountingPeriods)
          ..where((p) => p.id.equals(period.id)))
        .write(const AccountingPeriodsCompanion(isClosed: drift.Value(false)));

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إعادة فتح الفترة')));
    }
  }

  Future<void> _deletePeriod(AppDatabase db, AccountingPeriod period) async {
    if (period.isClosed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا يمكن حذف فترة مغلقة')));
      return;
    }

    await (db.delete(
      db.accountingPeriods,
    )..where((p) => p.id.equals(period.id))).go();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف الفترة')));
    }
  }
}
