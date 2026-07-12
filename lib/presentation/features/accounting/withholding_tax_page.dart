import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/accounting/wht_provider.dart';
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';

class WithholdingTaxPage extends StatefulWidget {
  const WithholdingTaxPage({super.key});

  @override
  State<WithholdingTaxPage> createState() => _WithholdingTaxPageState();
}

class _WithholdingTaxPageState extends State<WithholdingTaxPage> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final provider = context.read<WhtProvider>();
    provider.loadEntries(
      startDate: _startDate,
      endDate: _endDate,
      status: _statusFilter,
    );
    provider.loadSummary(_startDate, _endDate);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _loadData();
    }
  }

  String _formatAmount(Decimal amount) {
    final num = double.tryParse(amount.toString()) ?? 0.0;
    return NumberFormat('#,##0.00', 'ar_SA').format(num);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'معلق';
      case 'FILED':
        return 'مُقدَّم';
      case 'PAID':
        return 'مدفوع';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'FILED':
        return Colors.blue;
      case 'PAID':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _whtTypeLabel(String type) {
    switch (type) {
      case 'DIVIDENDS':
        return 'أرباح';
      case 'INTEREST':
        return 'فوائد';
      case 'ROYALTIES':
        return 'حقوق ملكية فكرية';
      case 'SERVICE_FEES':
        return 'أتعاب خدمات';
      case 'TECHNICAL_FEES':
        return 'أتعاب فنية';
      case 'COMMISSIONS':
        return 'عمولات';
      case 'RENT':
        return 'إيجار';
      case 'INSURANCE':
        return 'تأمين';
      default:
        return type;
    }
  }

  Future<void> _showMarkAsFiledDialog(WithholdingTaxEntry entry) async {
    final refController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تقديم الضريبة'),
        content: TextField(
          controller: refController,
          decoration: const InputDecoration(
            labelText: 'رقم المرجع',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (refController.text.trim().isEmpty) {
                AppSnackBar.warning(ctx, 'أدخل رقم المرجع');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      await context.read<WhtProvider>().markAsFiled(
            entry.id,
            refController.text.trim(),
          );
      if (mounted) {
        AppSnackBar.success(context, 'تم تقديم الضريبة بنجاح');
      }
    }
  }

  Future<void> _confirmMarkAsPaid(WithholdingTaxEntry entry) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الدفع'),
        content: const Text('هل أنت متأكد من تسجيل الدفع لهذه الضريبة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      await context.read<WhtProvider>().markAsPaid(entry.id);
      if (mounted) {
        AppSnackBar.success(context, 'تم تسجيل الدفع بنجاح');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ضريبة المصدر'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) {
              setState(() {
                _statusFilter = val == 'ALL' ? null : val;
              });
              _loadData();
            },
            icon: const Icon(Icons.filter_list),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'ALL', child: Text('الكل')),
              const PopupMenuItem(value: 'PENDING', child: Text('معلق')),
              const PopupMenuItem(value: 'FILED', child: Text('مُقدَّم')),
              const PopupMenuItem(value: 'PAID', child: Text('مدفوع')),
            ],
          ),
        ],
      ),
      body: Consumer<WhtProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.entries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildDateFilters(),
                const SizedBox(height: 12),
                _buildSummaryCard(provider),
                const SizedBox(height: 16),
                _buildRatesReference(),
                const SizedBox(height: 16),
                _buildEntriesHeader(provider),
                const SizedBox(height: 8),
                ...provider.entries.map(_buildEntryCard),
                if (provider.entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'لا توجد قيود ضريبية في هذا الفترة',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateFilters() {
    final fmt = DateFormat('yyyy-MM-dd');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickDate(isStart: true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'من تاريخ',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: Text(fmt.format(_startDate)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _pickDate(isStart: false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'إلى تاريخ',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: Text(fmt.format(_endDate)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(WhtProvider provider) {
    final summary = provider.summary;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملخص ضريبة المصدر',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryItem(
                  'عدد القيود',
                  summary != null ? '${summary.entryCount}' : '0',
                ),
                _summaryItem(
                  'إجمالي المبلغ',
                  summary != null ? _formatAmount(summary.totalGrossAmount) : '0.00',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryItem(
                  'ضريبة المصدر',
                  summary != null ? _formatAmount(summary.totalTaxAmount) : '0.00',
                ),
                _summaryItem(
                  'صافي المبلغ',
                  summary != null ? _formatAmount(summary.totalNetAmount) : '0.00',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRatesReference() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                const Text(
                  'معدلات ضريبة المصدر',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const Divider(),
            _rateRow('أرباح / فوائد', '5%'),
            _rateRow('حقوق ملكية فكرية / خدمات', '15%'),
            _rateRow('أتعاب فنية / عمولات / إيجار', '15%'),
            _rateRow('تأمين', '5%'),
          ],
        ),
      ),
    );
  }

  Widget _rateRow(String label, String rate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            rate,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesHeader(WhtProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'القيود (${provider.entries.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        if (_statusFilter != null)
          Chip(
            label: Text(_statusLabel(_statusFilter!)),
            backgroundColor: _statusColor(_statusFilter!),
            labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
            onDeleted: () {
              setState(() => _statusFilter = null);
              _loadData();
            },
          ),
      ],
    );
  }

  Widget _buildEntryCard(WithholdingTaxEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'دفعة: ${entry.paymentId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'FILED') {
                      _showMarkAsFiledDialog(entry);
                    } else if (val == 'PAID') {
                      _confirmMarkAsPaid(entry);
                    }
                  },
                  itemBuilder: (context) => [
                    if (entry.status == 'PENDING' || entry.status == 'FILED')
                      const PopupMenuItem(
                        value: 'FILED',
                        child: Text('تقديم الضريبة'),
                      ),
                    if (entry.status == 'FILED')
                      const PopupMenuItem(
                        value: 'PAID',
                        child: Text('تسجيل الدفع'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _infoChip('المورد', entry.supplierId),
                const SizedBox(width: 8),
                _infoChip('النوع', _whtTypeLabel(entry.paymentType)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _amountColumn('المبلغ الإجمالي', _formatAmount(entry.grossAmount)),
                _amountColumn(
                  'الضريبة (${entry.taxRate}%)',
                  _formatAmount(entry.taxAmount),
                ),
                _amountColumn('الصافي', _formatAmount(entry.netAmount)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy-MM-dd').format(entry.taxDate),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(entry.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(entry.status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountColumn(String label, String amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          amount,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
