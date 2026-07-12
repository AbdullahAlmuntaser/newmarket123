import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/sales/commission_provider.dart';
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';

class CommissionsPage extends StatefulWidget {
  const CommissionsPage({super.key});

  @override
  State<CommissionsPage> createState() => _CommissionsPageState();
}

class _CommissionsPageState extends State<CommissionsPage> {
  String? _selectedSalespersonId;
  String _selectedPeriod = _currentPeriod();
  final Set<String> _selectedCommissionIds = {};

  static String _currentPeriod() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final provider = context.read<CommissionProvider>();
    if (_selectedSalespersonId != null) {
      provider.loadData(
        salespersonId: _selectedSalespersonId,
        period: _selectedPeriod,
      );
    } else {
      provider.loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommissionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('العمولات'),
        actions: [
          if (_selectedCommissionIds.isNotEmpty)
            TextButton.icon(
              onPressed: () => _markSelectedAsPaid(context, provider),
              icon: const Icon(Icons.payment, color: Colors.white),
              label: Text(
                'تسديد المحدد (${_selectedCommissionIds.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltersSection(provider),
          if (_selectedSalespersonId != null) _buildSummaryCard(provider),
          if (_selectedSalespersonId != null) _buildTargetSection(provider),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCommissionsList(provider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTargetDialog(context, provider),
        icon: const Icon(Icons.add),
        label: const Text('إنشاء هدف مبيعات'),
      ),
    );
  }

  Widget _buildFiltersSection(CommissionProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: _selectedSalespersonId,
              decoration: const InputDecoration(
                labelText: 'مندوب المبيعات',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('الكل'),
                ),
                ...provider.salespersons.map((user) {
                  return DropdownMenuItem<String>(
                    value: user.id,
                    child: Text(user.fullName),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedSalespersonId = value;
                  _selectedCommissionIds.clear();
                });
                _loadData();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: const InputDecoration(
                labelText: 'الفترة',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _generatePeriodItems(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPeriod = value;
                    _selectedCommissionIds.clear();
                  });
                  _loadData();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _generatePeriodItems() {
    final items = <DropdownMenuItem<String>>[];
    final now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final period =
          '${date.year}-${date.month.toString().padLeft(2, '0')}';
      items.add(
        DropdownMenuItem(
          value: period,
          child: Text(
            '${date.year}/${date.month.toString().padLeft(2, '0')}',
          ),
        ),
      );
    }
    return items;
  }

  Widget _buildSummaryCard(CommissionProvider provider) {
    final summary = provider.summary;
    if (summary == null) return const SizedBox.shrink();

    final achievementPercent = summary.targetAmount > Decimal.zero
        ? (summary.totalSales.toDouble() / summary.targetAmount.toDouble() * 100)
            .clamp(0.0, 100.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملخص العمولات',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSummaryItem(
                  'إجمالي المبيعات',
                  summary.totalSales.toStringAsFixed(2),
                  Icons.shopping_cart,
                  Colors.blue,
                ),
                _buildSummaryItem(
                  'الهدف',
                  summary.targetAmount.toStringAsFixed(2),
                  Icons.flag,
                  Colors.orange,
                ),
                _buildSummaryItem(
                  'نسبة الإنجاز',
                  '${achievementPercent.toStringAsFixed(1)}%',
                  Icons.pie_chart,
                  summary.targetAchieved ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSummaryItem(
                  'إجمالي العمولة',
                  summary.totalCommission.toStringAsFixed(2),
                  Icons.monetization_on,
                  Colors.green,
                ),
                _buildSummaryItem(
                  'العدد',
                  '${summary.saleCount}',
                  Icons.receipt,
                  Colors.purple,
                ),
                _buildSummaryItem(
                  'الحالة',
                  summary.targetAchieved ? 'مُنجَز' : 'نشط',
                  summary.targetAchieved
                      ? Icons.check_circle
                      : Icons.hourglass_empty,
                  summary.targetAchieved ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSection(CommissionProvider provider) {
    final target = provider.currentTarget;
    if (target == null) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        child: ListTile(
          leading: const Icon(Icons.flag_outlined, color: Colors.orange),
          title: const Text('لا يوجد هدف لهذه الفترة'),
          subtitle: const Text('اضغط لإنشاء هدف مبيعات جديد'),
          trailing: const Icon(Icons.add_circle_outline),
          onTap: () => _showCreateTargetDialog(context, provider),
        ),
      );
    }

    final actualPercent = target.targetAmount > Decimal.zero
        ? (target.actualAmount.toDouble() / target.targetAmount.toDouble() * 100)
            .clamp(0.0, 100.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'هدف المبيعات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: target.status == 'ACHIEVED'
                        ? Colors.green[100]
                        : Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    target.status == 'ACHIEVED' ? 'مُنجَز' : 'نشط',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: target.status == 'ACHIEVED'
                          ? Colors.green[800]
                          : Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTargetStat(
                    'الهدف', target.targetAmount.toStringAsFixed(2)),
                const SizedBox(width: 16),
                _buildTargetStat(
                    'المحقق', target.actualAmount.toStringAsFixed(2)),
                const SizedBox(width: 16),
                _buildTargetStat(
                    'النسبة', '${actualPercent.toStringAsFixed(1)}%'),
                const SizedBox(width: 16),
                _buildTargetStat(
                    'عمولة', '${target.commissionRate.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: actualPercent / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                color: target.status == 'ACHIEVED' ? Colors.green : Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildCommissionsList(CommissionProvider provider) {
    if (provider.commissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monetization_on_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'لا توجد عمولات',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'سيتم احتساب العمولات تلقائياً عند تسجيل المبيعات',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: provider.commissions.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final commission = provider.commissions[index];
        final isSelected = _selectedCommissionIds.contains(commission.id);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withAlpha(50)
              : null,
          child: ListTile(
            leading: GestureDetector(
              onTap: () => _toggleSelection(commission.id),
              child: CircleAvatar(
                backgroundColor: commission.status == 'PAID'
                    ? Colors.green[100]
                    : Colors.orange[100],
                child: commission.status == 'PAID'
                    ? const Icon(Icons.check, color: Colors.green)
                    : const Icon(Icons.hourglass_empty,
                        color: Colors.orange),
              ),
            ),
            title: FutureBuilder<User?>(
              future: _getSalespersonName(commission.salespersonId),
              builder: (context, snapshot) {
                return Text(
                  snapshot.data?.fullName ?? commission.salespersonId,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                );
              },
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  'فاتورة: #${commission.saleId.length > 8 ? commission.saleId.substring(0, 8) : commission.saleId}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  'التاريخ: ${DateFormat.yMMMd().format(commission.createdAt)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  commission.commissionAmount.toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: commission.status == 'PAID'
                        ? Colors.green
                        : Colors.blue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'المبيع: ${commission.saleAmount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                Text(
                  'النسبة: ${commission.commissionRate.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                _buildStatusChip(commission.status),
              ],
            ),
            onTap: () => _toggleSelection(commission.id),
            onLongPress: () {
              if (commission.status == 'PENDING') {
                _showMarkAsPaidDialog(context, provider, [commission.id]);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    final isPaid = status == 'PAID';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green[100] : Colors.orange[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isPaid ? 'مدفوع' : 'معلق',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isPaid ? Colors.green[800] : Colors.orange[800],
        ),
      ),
    );
  }

  void _toggleSelection(String commissionId) {
    setState(() {
      if (_selectedCommissionIds.contains(commissionId)) {
        _selectedCommissionIds.remove(commissionId);
      } else {
        _selectedCommissionIds.add(commissionId);
      }
    });
  }

  Future<User?> _getSalespersonName(String salespersonId) async {
    final db = context.read<AppDatabase>();
    return await (db.select(db.users)
          ..where((u) => u.id.equals(salespersonId)))
        .getSingleOrNull();
  }

  void _showCreateTargetDialog(
      BuildContext context, CommissionProvider provider) {
    if (provider.salespersons.isEmpty) {
      AppSnackBar.warning(context, 'لا يوجد مندوبين مسجلين');
      return;
    }

    String? selectedSalespersonId =
        provider.salespersons.isNotEmpty ? provider.salespersons.first.id : null;
    final periodController =
        TextEditingController(text: _selectedPeriod);
    final targetController = TextEditingController();
    final rateController = TextEditingController(text: '5');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء هدف مبيعات'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedSalespersonId,
                  decoration: const InputDecoration(
                    labelText: 'مندوب المبيعات',
                    isDense: true,
                  ),
                  items: provider.salespersons.map((user) {
                    return DropdownMenuItem<String>(
                      value: user.id,
                      child: Text(user.fullName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedSalespersonId = value;
                  },
                  validator: (value) =>
                      value == null ? 'الرجاء اختيار مندوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: periodController,
                  decoration: const InputDecoration(
                    labelText: 'الفترة (YYYY-MM)',
                    isDense: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال الفترة';
                    }
                    final regex = RegExp(r'^\d{4}-\d{2}$');
                    if (!regex.hasMatch(value)) {
                      return 'الصيغة: YYYY-MM';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: targetController,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المستهدف',
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال المبلغ';
                    }
                    if (double.tryParse(value) == null) {
                      return 'أدخل رقماً صحيحاً';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: rateController,
                  decoration: const InputDecoration(
                    labelText: 'نسبة العمولة (%)',
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال النسبة';
                    }
                    final rate = double.tryParse(value);
                    if (rate == null || rate <= 0 || rate > 100) {
                      return 'أدخل نسبة بين 1 و 100';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;

              try {
                final targetAmount =
                    Decimal.parse(targetController.text);
                final commissionRate =
                    Decimal.parse(rateController.text);

                await provider.createTarget(
                  salespersonId: selectedSalespersonId!,
                  period: periodController.text,
                  targetAmount: targetAmount,
                  commissionRate: commissionRate,
                );

                if (!context.mounted) return;
                Navigator.pop(context);
                AppSnackBar.success(context, 'تم إنشاء الهدف بنجاح');

                setState(() {
                  _selectedSalespersonId = selectedSalespersonId;
                  _selectedPeriod = periodController.text;
                });
                _loadData();
              } catch (e) {
                if (!context.mounted) return;
                AppSnackBar.error(
                    context, 'فشل إنشاء الهدف: ${e.toString()}');
              }
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  void _markSelectedAsPaid(
      BuildContext context, CommissionProvider provider) {
    final pendingIds = _selectedCommissionIds.where((id) {
      final c = provider.commissions.firstWhere((c) => c.id == id);
      return c.status == 'PENDING';
    }).toList();

    if (pendingIds.isEmpty) {
      AppSnackBar.warning(context, 'لا توجد عمولات معلقة محددة');
      return;
    }

    _showMarkAsPaidDialog(context, provider, pendingIds);
  }

  void _showMarkAsPaidDialog(
    BuildContext context,
    CommissionProvider provider,
    List<String> commissionIds,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد التسديد'),
        content: Text(
          'هل تريد تسديد ${commissionIds.length} عمولة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await provider.markAsPaid(commissionIds);
                if (!context.mounted) return;
                Navigator.pop(context);
                setState(() {
                  _selectedCommissionIds.clear();
                });
                AppSnackBar.success(
                    context, 'تم تسديد العمولات بنجاح');
              } catch (e) {
                if (!context.mounted) return;
                AppSnackBar.error(
                    context, 'فشل التسديد: ${e.toString()}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('تسديد',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
