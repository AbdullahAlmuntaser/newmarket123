import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/budget_service.dart';
import 'package:supermarket/injection_container.dart';
import 'package:intl/intl.dart';

class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedPeriod = DateTime.now().year.toString();
  int? _selectedCostCenterId;
  int? _selectedAccountId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final budgetService = sl<BudgetService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الميزانيات التقديرية'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'الميزانيات'),
            Tab(icon: Icon(Icons.add_circle), text: 'إنشاء ميزانية'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBudgetsList(db),
          _buildCreateBudgetForm(db, budgetService),
        ],
      ),
    );
  }

  Widget _buildBudgetsList(AppDatabase db) {
    return StreamBuilder<List<AccBudget>>(
      stream: (db.select(db.accBudgets)
            ..orderBy([(b) => drift.OrderingTerm.desc(b.createdAt)]))
          .watch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final budgets = snapshot.data ?? [];
        
        if (budgets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_outlined, 
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('لا توجد ميزانيات تقديرية', 
                    style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                const SizedBox(height: 8),
                const Text('قم بإنشاء ميزانية جديدة من التبويب الثاني'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: budgets.length,
          itemBuilder: (context, index) {
            final budget = budgets[index];
            final progress = budget.budgetedAmount > 0 
                ? budget.actualAmount / budget.budgetedAmount 
                : 0.0;
            final variance = budget.budgetedAmount - budget.actualAmount;
            final isOverBudget = variance < 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            budget.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: budget.status == 'active' 
                                ? Colors.green.shade100 
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            budget.status == 'active' ? 'نشط' : 'مغلق',
                            style: TextStyle(
                              color: budget.status == 'active' 
                                  ? Colors.green.shade700 
                                  : Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('الفترة: ${budget.period}', 
                        style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildBudgetInfo(
                          'المudgeted',
                          NumberFormat.currency(symbol: '').format(budget.budgetedAmount),
                          Colors.blue,
                        ),
                        _buildBudgetInfo(
                          'الفعلي',
                          NumberFormat.currency(symbol: '').format(budget.actualAmount),
                          Colors.orange,
                        ),
                        _buildBudgetInfo(
                          'التباين',
                          NumberFormat.currency(symbol: '').format(variance),
                          isOverBudget ? Colors.red : Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(
                          progress > 1.0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}% مستهلك',
                      style: TextStyle(
                        color: progress > 1.0 ? Colors.red : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBudgetInfo(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCreateBudgetForm(AppDatabase db, BudgetService budgetService) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الميزانية',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال اسم الميزانية';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: const InputDecoration(
                labelText: 'الفترة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              items: _buildPeriodItems(),
              onChanged: (value) => setState(() => _selectedPeriod = value!),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<CostCenter>>(
              future: (db.select(db.costCenters)..where((c) => c.isActive.equals(true))).get(),
              builder: (context, snapshot) {
                final costCenters = snapshot.data ?? [];
                return DropdownButtonFormField<int?>(
                  value: _selectedCostCenterId,
                  decoration: const InputDecoration(
                    labelText: 'مركز التكلفة (اختياري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('عام')),
                    ...costCenters.map((c) => DropdownMenuItem(
                      value: int.tryParse(c.id),
                      child: Text(c.name),
                    )),
                  ],
                  onChanged: (value) => setState(() => _selectedCostCenterId = value),
                );
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<GLAccount>>(
              future: (db.select(db.gLAccounts)).get(),
              builder: (context, snapshot) {
                final accounts = snapshot.data ?? [];
                return DropdownButtonFormField<int?>(
                  value: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'الحساب المحاسبي (اختياري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('عام')),
                    ...accounts.where((a) => a.type == 'EXPENSE').map((a) => 
                      DropdownMenuItem(value: int.tryParse(a.id), child: Text(a.name)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedAccountId = value),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'المبلغ المقدر',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                suffixText: 'ريال',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال المبلغ';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'يرجى إدخال مبلغ صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _createBudget(db),
              icon: _isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isLoading ? 'جاري الإنشاء...' : 'إنشاء ميزانية'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildPeriodItems() {
    final currentYear = DateTime.now().year;
    return [
      DropdownMenuItem(value: currentYear.toString(), child: Text('$currentYear')),
      DropdownMenuItem(value: '${currentYear - 1}', child: Text('${currentYear - 1}')),
      DropdownMenuItem(value: '${currentYear - 2}', child: Text('${currentYear - 2}')),
      DropdownMenuItem(value: '$currentYear-Q1', child: Text('$currentYear - الربع الأول')),
      DropdownMenuItem(value: '$currentYear-Q2', child: Text('$currentYear - الربع الثاني')),
      DropdownMenuItem(value: '$currentYear-Q3', child: Text('$currentYear - الربع الثالث')),
      DropdownMenuItem(value: '$currentYear-Q4', child: Text('$currentYear - الربع الرابع')),
    ];
  }

  Future<void> _createBudget(AppDatabase db) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await db.into(db.accBudgets).insert(
        AccBudgetsCompanion.insert(
          name: _nameController.text,
          period: _selectedPeriod,
          costCenterId: drift.Value(_selectedCostCenterId?.toString()),
          accountId: drift.Value(_selectedAccountId?.toString()),
          budgetedAmount: double.parse(_amountController.text),
          variance: double.parse(_amountController.text),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الميزانية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _nameController.clear();
        _amountController.clear();
        setState(() {
          _selectedCostCenterId = null;
          _selectedAccountId = null;
        });
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}