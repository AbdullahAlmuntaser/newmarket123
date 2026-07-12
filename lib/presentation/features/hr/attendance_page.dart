import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/attendance_service.dart';
import 'package:supermarket/presentation/features/hr/attendance_provider.dart';
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';
import 'package:intl/intl.dart' as intl;

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  Employee? _selectedEmployee;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    if (_selectedEmployee == null) return;
    final provider = context.read<AttendanceProvider>();
    provider.loadAttendance(
      _selectedEmployee!.id,
      startDate: _startDate,
      endDate: _endDate,
    );
    provider.loadSummary(_selectedEmployee!.id, _startDate, _endDate);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final db = Provider.of<AppDatabase>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الحضور والانصراف'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                FutureBuilder<List<Employee>>(
                  future: db.select(db.employees).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    return DropdownButtonFormField<Employee>(
                      value: _selectedEmployee,
                      decoration: const InputDecoration(
                        labelText: 'الموظف',
                        border: OutlineInputBorder(),
                      ),
                      items: snapshot.data!
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.name),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _selectedEmployee = v);
                        _loadData();
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateField(
                        context,
                        label: 'من تاريخ',
                        date: _startDate,
                        onTap: (date) {
                          setState(() => _startDate = date);
                          _loadData();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateField(
                        context,
                        label: 'إلى تاريخ',
                        date: _endDate,
                        onTap: (date) {
                          setState(() => _endDate = date);
                          _loadData();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_selectedEmployee != null)
                  _buildClockButtons(provider, colorScheme),
              ],
            ),
          ),
          if (provider.summary != null) _buildSummary(provider.summary!),
          const Divider(height: 1),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.records.isEmpty
                    ? const Center(child: Text('لا توجد سجلات حضور'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: provider.records.length,
                        itemBuilder: (context, index) {
                          final record = provider.records[index];
                          return _buildRecordCard(record, colorScheme);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    BuildContext context, {
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onTap,
  }) {
    final controller = TextEditingController(
      text: intl.DateFormat('yyyy-MM-dd').format(date),
    );
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onTap(picked);
      },
    );
  }

  Widget _buildClockButtons(AttendanceProvider provider, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: provider.isLoading
                ? null
                : () async {
                    try {
                      await provider.clockIn(_selectedEmployee!.id);
                      if (!mounted) return;
                      AppSnackBar.success(context, 'تم تسجيل الحضور بنجاح');
                      _loadData();
                    } catch (e) {
                      if (!mounted) return;
                      AppSnackBar.error(context, 'خطأ: $e');
                    }
                  },
            icon: const Icon(Icons.login),
            label: const Text('تسجيل حضور'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: provider.isLoading
                ? null
                : () async {
                    try {
                      await provider.clockOut(_selectedEmployee!.id);
                      if (!mounted) return;
                      AppSnackBar.success(context, 'تم تسجيل الانصراف بنجاح');
                      _loadData();
                    } catch (e) {
                      if (!mounted) return;
                      AppSnackBar.error(context, 'خطأ: $e');
                    }
                  },
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل انصراف'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(AttendanceSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملخص الحضور',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _summaryItem('إجمالي الأيام', '${summary.presentDays + summary.absentDays + summary.lateDays + summary.earlyLeaveDays + summary.onLeaveDays}'),
              _summaryItem('حاضر', '${summary.presentDays}', color: Colors.green),
              _summaryItem('متأخر', '${summary.lateDays}', color: Colors.orange),
              _summaryItem('انصراف مبكر', '${summary.earlyLeaveDays}', color: Colors.orange),
              _summaryItem('غائب', '${summary.absentDays}', color: Colors.red),
              _summaryItem('إجازة', '${summary.onLeaveDays}', color: Colors.blue),
              _summaryItem('ساعات إضافية', '${summary.totalOvertimeHours}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, {Color? color}) {
    return Chip(
      avatar: color != null
          ? CircleAvatar(backgroundColor: color, radius: 8)
          : null,
      label: Text('$label: $value'),
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }

  Widget _buildRecordCard(AttendanceRecord record, ColorScheme colorScheme) {
    final statusText = _statusArabic(record.status);
    final statusColor = _statusColor(record.status);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  intl.DateFormat('yyyy-MM-dd').format(record.clockIn),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Chip(
                  label: Text(
                    statusText,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: statusColor,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.login, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Text('الحضور: ${intl.DateFormat('HH:mm').format(record.clockIn)}'),
                const SizedBox(width: 20),
                const Icon(Icons.logout, size: 16, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  record.clockOut != null
                      ? 'الانصراف: ${intl.DateFormat('HH:mm').format(record.clockOut!)}'
                      : 'لم يسجل انصراف',
                ),
              ],
            ),
            if (record.overtimeHours != Decimal.zero) ...[
              const SizedBox(height: 6),
              Text(
                'ساعات إضافية: ${record.overtimeHours}',
                style: TextStyle(color: colorScheme.primary, fontSize: 13),
              ),
            ],
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'ملاحظات: ${record.notes}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusArabic(String status) {
    switch (status) {
      case 'PRESENT':
        return 'حاضر';
      case 'LATE':
        return 'متأخر';
      case 'EARLY_LEAVE':
        return 'انصراف مبكر';
      case 'ABSENT':
        return 'غائب';
      case 'ON_LEAVE':
        return 'إجازة';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PRESENT':
        return Colors.green;
      case 'LATE':
        return Colors.orange;
      case 'EARLY_LEAVE':
        return Colors.orange;
      case 'ABSENT':
        return Colors.red;
      case 'ON_LEAVE':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
