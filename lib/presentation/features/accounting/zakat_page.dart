import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/accounting/zakat_provider.dart';
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';

class ZakatPage extends StatefulWidget {
  const ZakatPage({super.key});

  @override
  State<ZakatPage> createState() => _ZakatPageState();
}

class _ZakatPageState extends State<ZakatPage> {
  String _selectedPeriod = DateTime.now().year.toString();
  String _selectedType = 'ANNUAL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ZakatProvider>().loadData(period: _selectedPeriod);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ZakatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الزكاة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            tooltip: 'حساب زكاة جديد',
            onPressed: () => _showCalculateDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCards(provider),
          _buildFilters(),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.calculations.isEmpty
                    ? const Center(child: Text('لا توجد حسابات زكاة'))
                    : _buildCalculationsList(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(ZakatProvider provider) {
    final summary = provider.summary;
    if (summary == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              title: 'إجمالي الزكاة',
              value: '${summary.totalZakat} ر.س',
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(
              title: 'المدفوعة',
              value: '${summary.paidZakat} ر.س',
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(
              title: 'المعلقة',
              value: '${summary.pendingZakat} ر.س',
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: const InputDecoration(
                labelText: 'الفترة',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: List.generate(5, (i) {
                final year = DateTime.now().year - i;
                return DropdownMenuItem(
                  value: year.toString(),
                  child: Text(year.toString()),
                );
              }),
              onChanged: (value) {
                setState(() => _selectedPeriod = value!);
                context.read<ZakatProvider>().loadData(period: _selectedPeriod);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'نوع الحساب',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'ANNUAL', child: Text('سنوي')),
                DropdownMenuItem(value: 'QUARTERLY', child: Text('ربع سنوي')),
              ],
              onChanged: (value) {
                setState(() => _selectedType = value!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationsList(ZakatProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.calculations.length,
      itemBuilder: (context, index) {
        final calc = provider.calculations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(calc.status).withOpacity(0.1),
              child: Icon(
                _statusIcon(calc.status),
                color: _statusColor(calc.status),
                size: 20,
              ),
            ),
            title: Text('فترة: ${calc.period}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الأصول: ${calc.totalAssets} ر.س | الخصوم: ${calc.totalLiabilities} ر.س'),
                Text(
                  'الزكاة: ${calc.zakatAmount} ر.س',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('الحالة: ${_statusText(calc.status)}'),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (action) => _handleAction(context, action, calc),
              itemBuilder: (context) => [
                if (calc.status == 'DRAFT') ...[
                  const PopupMenuItem(value: 'file', child: Text('تقديم')),
                  const PopupMenuItem(value: 'pay', child: Text('دفع')),
                ],
                if (calc.status == 'FILED')
                  const PopupMenuItem(value: 'pay', child: Text('دفع')),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCalculateDialog(BuildContext context) {
    final yearController = TextEditingController(
      text: DateTime.now().year.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حساب الزكاة'),
        content: TextField(
          controller: yearController,
          decoration: const InputDecoration(
            labelText: 'الفترة (السنة)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = context.read<ZakatProvider>();
              await provider.calculateZakat(
                period: yearController.text,
                calculationType: _selectedType,
              );
              if (context.mounted) {
                AppSnackBar.success(context, 'تم حساب الزكاة بنجاح');
              }
            },
            child: const Text('حساب'),
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action, ZakatCalculation calc) {
    final provider = context.read<ZakatProvider>();
    switch (action) {
      case 'file':
        provider.markAsFiled(calc.id);
        AppSnackBar.success(context, 'تم تقديم الزكاة');
        break;
      case 'pay':
        provider.markAsPaid(calc.id);
        AppSnackBar.success(context, 'تم دفع الزكاة');
        break;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PAID': return Colors.green;
      case 'FILED': return Colors.blue;
      default: return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'PAID': return Icons.check_circle;
      case 'FILED': return Icons.send;
      default: return Icons.edit_note;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'PAID': return 'مدفوعة';
      case 'FILED': return 'مقدمة';
      default: return 'مسودة';
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
