// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/recurring_entry_service.dart';
import 'package:supermarket/injection_container.dart';

class RecurringEntriesPage extends StatefulWidget {
  const RecurringEntriesPage({super.key});

  @override
  State<RecurringEntriesPage> createState() => _RecurringEntriesPageState();
}

class _RecurringEntriesPageState extends State<RecurringEntriesPage> {
  late final RecurringEntryService _service;

  @override
  void initState() {
    super.initState();
    _service = RecurringEntryService(sl<AppDatabase>());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('القيود المحاسبية الدورية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'تنفيذ القيود المستحقة',
            onPressed: _executeDueEntries,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'إضافة قيد دوري جديد',
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<RecurringEntry>>(
        stream: _service.watchAllEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.replay, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد قيود دورية',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('اضغط + لإضافة قيد دوري جديد',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: entries.length,
            itemBuilder: (context, index) =>
                _buildEntryCard(context, entries[index]),
          );
        },
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, RecurringEntry entry) {
    final frequencyMap = {
      'DAILY': 'يومي',
      'WEEKLY': 'أسبوعي',
      'BIWEEKLY': 'كل أسبوعين',
      'MONTHLY': 'شهري',
      'QUARTERLY': 'ربع سنوي',
      'YEARLY': 'سنوي',
    };
    final statusMap = {
      'active': ('نشط', Colors.green),
      'paused': ('متوقف', Colors.orange),
      'completed': ('مكتمل', Colors.blue),
    };

    final statusInfo = statusMap[entry.status] ?? ('غير معروف', Colors.grey);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusInfo.$2.withOpacity(0.2),
          child: Icon(
            entry.status == 'active' ? Icons.replay : Icons.pause,
            color: statusInfo.$2,
          ),
        ),
        title: Text(entry.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${frequencyMap[entry.frequency] ?? entry.frequency} | ${entry.amount}'),
            Text(
              'من: ${entry.debitAccountCode} إلى: ${entry.creditAccountCode}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'التنفيذ التالي: ${entry.nextExecutionDate.toString().substring(0, 10)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'المنفّذ: ${entry.totalExecutions}${entry.maxExecutions != null ? '/${entry.maxExecutions}' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, value, entry),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('تعديل')),
            PopupMenuItem(
              value: entry.status == 'active' ? 'pause' : 'resume',
              child: Text(entry.status == 'active' ? 'إيقاف مؤقت' : 'استئناف'),
            ),
            const PopupMenuItem(value: 'execute', child: Text('تنفيذ الآن')),
            const PopupMenuItem(value: 'history', child: Text('سجل التنفيذ')),
            const PopupMenuItem(value: 'delete', child: Text('حذف')),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _handleMenuAction(
      BuildContext context, String action, RecurringEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case 'edit':
        _showEditDialog(context, entry);
        break;
      case 'pause':
        await _service.pauseEntry(entry.id);
        break;
      case 'resume':
        await _service.resumeEntry(entry.id);
        break;
      case 'execute':
        try {
          await _service.executeEntryNow(entry.id);
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('تم تنفيذ القيد بنجاح')),
          );
        } catch (e) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(content: Text('خطأ: $e')),
          );
        }
        break;
      case 'history':
        _showExecutionHistory(context, entry);
        break;
      case 'delete':
        _confirmDelete(context, entry);
        break;
    }
  }

  Future<void> _executeDueEntries() async {
    final result = await _service.executeDueEntries();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم التنفيذ: ${result.successCount} نجح، ${result.failCount} فشل',
          ),
        ),
      );
    }
  }

  void _showAddDialog(BuildContext context) {
    _showEntryForm(context, null);
  }

  void _showEditDialog(BuildContext context, RecurringEntry entry) {
    _showEntryForm(context, entry);
  }

  void _showEntryForm(BuildContext context, RecurringEntry? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl =
        TextEditingController(text: existing?.amount.toString() ?? '');
    final debitCtrl =
        TextEditingController(text: existing?.debitAccountCode ?? '');
    final creditCtrl =
        TextEditingController(text: existing?.creditAccountCode ?? '');
    String frequency = existing?.frequency ?? 'MONTHLY';
    String referenceType = existing?.referenceType ?? 'EXPENSE';
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime? endDate = existing?.endDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة قيد دوري' : 'تعديل القيد الدوري'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'اسم القيد', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                      labelText: 'المبلغ', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: debitCtrl,
                  decoration: const InputDecoration(
                      labelText: 'كود حساب المدين', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: creditCtrl,
                  decoration: const InputDecoration(
                      labelText: 'كود حساب الدائن', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(
                      labelText: 'التكرار', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'DAILY', child: Text('يومي')),
                    DropdownMenuItem(value: 'WEEKLY', child: Text('أسبوعي')),
                    DropdownMenuItem(value: 'MONTHLY', child: Text('شهري')),
                    DropdownMenuItem(value: 'QUARTERLY', child: Text('ربع سنوي')),
                    DropdownMenuItem(value: 'YEARLY', child: Text('سنوي')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => frequency = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: referenceType,
                  decoration: const InputDecoration(
                      labelText: 'نوع المرجع', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'EXPENSE', child: Text('مصروف')),
                    DropdownMenuItem(value: 'REVENUE', child: Text('إيراد')),
                    DropdownMenuItem(value: 'CUSTOM', child: Text('مخصص')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => referenceType = v);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('تاريخ البدء'),
                  subtitle: Text(startDate.toString().substring(0, 10)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => startDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || amountCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
                  );
                  return;
                }
                try {
                  if (existing == null) {
                    await _service.createEntry(
                      name: nameCtrl.text,
                      frequency: frequency,
                      referenceType: referenceType,
                      debitAccountCode: debitCtrl.text,
                      creditAccountCode: creditCtrl.text,
                      amount: Decimal.parse(amountCtrl.text),
                      startDate: startDate,
                      endDate: endDate,
                    );
                  } else {
                    await _service.updateEntry(existing.copyWith(
                      name: nameCtrl.text,
                      frequency: frequency,
                      referenceType: referenceType,
                      debitAccountCode: debitCtrl.text,
                      creditAccountCode: creditCtrl.text,
                      amount: Decimal.parse(amountCtrl.text),
                      startDate: startDate,
                      endDate: drift.Value(endDate),
                    ));
                  }
                  if (!mounted) return;
                  Navigator.pop(context);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e')),
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExecutionHistory(BuildContext context, RecurringEntry entry) async {
    final history = await _service.getExecutionHistory(entry.id);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('سجل التنفيذ - ${entry.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Text('لا يوجد سجل تنفيذ')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final exec = history[index];
                    return ListTile(
                      leading: Icon(
                        exec.status == 'posted'
                            ? Icons.check_circle
                            : Icons.error,
                        color: exec.status == 'posted'
                            ? Colors.green
                            : Colors.red,
                      ),
                      title: Text(exec.executionDate.toString().substring(0, 16)),
                      subtitle: Text(exec.status),
                      trailing: exec.errorMessage != null
                          ? const Icon(Icons.info, color: Colors.orange)
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, RecurringEntry entry) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف "${entry.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _service.deleteEntry(entry.id);
              if (!mounted) return;
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
