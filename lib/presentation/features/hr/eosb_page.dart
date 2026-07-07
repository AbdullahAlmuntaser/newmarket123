import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/presentation/features/hr/eosb_provider.dart';
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class EOSBPage extends StatefulWidget {
  const EOSBPage({super.key});

  @override
  State<EOSBPage> createState() => _EOSBPageState();
}

class _EOSBPageState extends State<EOSBPage> {
  String _selectedStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EOSBProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EOSBProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('مكافآت نهاية الخدمة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            tooltip: 'حساب مكافأة جديدة',
            onPressed: () => _showCalculateDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCards(provider),
          _buildStatusFilter(),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.eosbList.isEmpty
                    ? const Center(child: Text('لا توجد حسابات مكافآت'))
                    : _buildEOSBList(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(EOSBProvider provider) {
    final summary = provider.summary;
    if (summary == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              title: 'إجمالي المكافآت',
              value: '${summary.totalEOSB} ر.س',
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(
              title: 'المدفوعة',
              value: '${summary.paidEOSB} ر.س',
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(
              title: 'المعلقة',
              value: '${summary.pendingEOSB} ر.س',
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'ALL', label: Text('الكل')),
          ButtonSegment(value: 'CALCULATED', label: Text('محسوبة')),
          ButtonSegment(value: 'PAID', label: Text('مدفوعة')),
        ],
        selected: {_selectedStatus},
        onSelectionChanged: (Set<String> selected) {
          setState(() => _selectedStatus = selected.first);
          final provider = context.read<EOSBProvider>();
          provider.loadData(
            status: _selectedStatus == 'ALL' ? null : _selectedStatus,
          );
        },
      ),
    );
  }

  Widget _buildEOSBList(EOSBProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.eosbList.length,
      itemBuilder: (context, index) {
        final eosb = provider.eosbList[index];
        final employee = provider.employees.firstWhere(
          (e) => e.id == eosb.employeeId,
          orElse: () => provider.employees.first,
        );
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(eosb.status).withOpacity(0.1),
              child: Icon(
                _statusIcon(eosb.status),
                color: _statusColor(eosb.status),
                size: 20,
              ),
            ),
            title: Text(employee.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سنوات الخدمة: ${eosb.totalYearsOfService}'),
                Text(
                  'المكافأة: ${eosb.eosbAmount} ر.س',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('طريقة الحساب: ${eosb.calculationMethod}'),
              ],
            ),
            isThreeLine: true,
            trailing: eosb.status != 'PAID'
                ? IconButton(
                    icon: const Icon(Icons.payment, color: Colors.green),
                    onPressed: () => _markAsPaid(context, eosb),
                  )
                : null,
          ),
        );
      },
    );
  }

  void _showCalculateDialog(BuildContext context) {
    final provider = context.read<EOSBProvider>();
    String? selectedEmployeeId;
    String calculationMethod = 'STANDARD';
    final endDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('حساب مكافأة نهاية الخدمة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedEmployeeId,
                decoration: const InputDecoration(
                  labelText: 'الموظف',
                  border: OutlineInputBorder(),
                ),
                items: provider.employees
                    .map((e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  setDialogState(() => selectedEmployeeId = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endDateController,
                decoration: const InputDecoration(
                  labelText: 'تاريخ النهاية',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: calculationMethod,
                decoration: const InputDecoration(
                  labelText: 'طريقة الحساب',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'STANDARD', child: Text('قياسية')),
                  DropdownMenuItem(value: 'ENHANCED', child: Text('متقدمة')),
                ],
                onChanged: (value) {
                  setDialogState(() => calculationMethod = value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: selectedEmployeeId == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      final endDate = DateFormat('yyyy-MM-dd')
                          .parse(endDateController.text);
                      final eosb = await provider.calculateEOSB(
                        employeeId: selectedEmployeeId!,
                        endDate: endDate,
                        calculationMethod: calculationMethod,
                      );
                      if (context.mounted) {
                        if (eosb != null) {
                          AppSnackBar.success(
                            context,
                            'تم حساب المكافأة: ${eosb.eosbAmount} ر.س',
                          );
                        } else {
                          AppSnackBar.error(
                            context,
                            'خطأ في الحساب',
                          );
                        }
                      }
                    },
              child: const Text('حساب'),
            ),
          ],
        ),
      ),
    );
  }

  void _markAsPaid(BuildContext context, EndOfServiceBenefit eosb) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الدفع'),
        content: Text('هل تريد تسجيل مكافأة ${eosb.eosbAmount} ر.س كمدفوعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<EOSBProvider>().markAsPaid(eosb.id);
              AppSnackBar.success(context, 'تم تسجيل الدفع');
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PAID': return Colors.green;
      case 'VOIDED': return Colors.red;
      default: return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'PAID': return Icons.check_circle;
      case 'VOIDED': return Icons.cancel;
      default: return Icons.calculate;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
