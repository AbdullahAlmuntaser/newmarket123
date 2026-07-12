import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/bank_reconciliation_service.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:intl/intl.dart';

class BankReconciliationPage extends StatefulWidget {
  const BankReconciliationPage({super.key});

  @override
  State<BankReconciliationPage> createState() => _BankReconciliationPageState();
}

class _BankReconciliationPageState extends State<BankReconciliationPage> {
  String? _selectedAccountId;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  List<UnmatchedTransaction> _transactions = [];
  final Set<String> _selectedTxIds = {};
  bool _isLoading = false;
  bool _selectAll = false;
  final _actualBalanceController = TextEditingController();
  final _toleranceController = TextEditingController(text: '0.01');
  final _noteController = TextEditingController();
  double _bookBalance = 0.0;

  late BankReconciliationService _reconciliationService;
  late AppDatabase _db;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _db = context.read<AppDatabase>();
    _reconciliationService = BankReconciliationService(_db);
  }

  @override
  void dispose() {
    _actualBalanceController.dispose();
    _toleranceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسوية البنك'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFilterRow(),
            const SizedBox(height: 16),
            if (_selectedAccountId != null) ...[
              _buildBalanceSummary(),
              const SizedBox(height: 16),
              _buildTransactionList(),
            ] else
              const Expanded(
                child: Center(
                  child: Text(
                    'اختر حساب بنك للبدء بالتسوية',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: StreamBuilder<List<GLAccount>>(
                    stream: (_db.select(_db.gLAccounts)
                          ..where((t) =>
                              t.code.equals(AccountingService.codeBank) |
                              t.code.like('112%'))
                          ..orderBy(
                              [(t) => drift.OrderingTerm(expression: t.code)]))
                        .watch(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      final accounts = snapshot.data!;
                      return DropdownButtonFormField<String>(
                        value: _selectedAccountId,
                        decoration: const InputDecoration(
                          labelText: 'حساب البنك',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: accounts
                            .map((a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text('${a.code} - ${a.name}'),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedAccountId = val;
                            _selectedTxIds.clear();
                            _selectAll = false;
                          });
                          _loadTransactions();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildDateField(
                    label: 'من تاريخ',
                    date: _fromDate,
                    onChanged: (d) => setState(() => _fromDate = d),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildDateField(
                    label: 'إلى تاريخ',
                    date: _toDate,
                    onChanged: (d) => setState(() => _toDate = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _actualBalanceController,
                    decoration: const InputDecoration(
                      labelText: 'الرصيد الفعلي (كشف البنك)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _toleranceController,
                    decoration: const InputDecoration(
                      labelText: 'التحمّل',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _loadTransactions,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('بحث'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required Function(DateTime) onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(DateFormat('yyyy-MM-dd').format(date)),
      ),
    );
  }

  Widget _buildBalanceSummary() {
    final actual = double.tryParse(_actualBalanceController.text) ?? 0.0;
    final diff = actual - _bookBalance;

    return Card(
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            _summaryItem('الرصيد الدفتري', _bookBalance, Colors.blue),
            const SizedBox(width: 24),
            _summaryItem('الرصيد الفعلي', actual, Colors.green),
            const SizedBox(width: 24),
            _summaryItem(
              'الفارق',
              diff,
              diff == 0
                  ? Colors.green
                  : diff > 0
                      ? Colors.orange
                      : Colors.red,
            ),
            const SizedBox(width: 24),
            _summaryItem(
              'المعاملات المحددة',
              _selectedTxIds.length.toDouble(),
              Colors.purple,
              isCount: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, double value, Color color,
      {bool isCount = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          isCount ? '${value.toInt()}' : '${value.toStringAsFixed(2)} ر.س',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    return Expanded(
      child: Card(
        child: Column(
          children: [
            _buildListHeader(),
            const Divider(height: 1),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_transactions.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'لا توجد معاملات غير مسوّاة',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    final isSelected = _selectedTxIds.contains(tx.glLineId);
                    return _buildTransactionRow(tx, isSelected);
                  },
                ),
              ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: _selectAll,
              onChanged: (val) {
                setState(() {
                  _selectAll = val ?? false;
                  if (_selectAll) {
                    _selectedTxIds.addAll(_transactions.map((t) => t.glLineId));
                  } else {
                    _selectedTxIds.clear();
                  }
                });
              },
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text('التاريخ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const Expanded(
            flex: 3,
            child: Text('الوصف',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const Expanded(
            flex: 2,
            child: Text('المرجع',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const Expanded(
            flex: 2,
            child: Text('المبلغ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(UnmatchedTransaction tx, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedTxIds.remove(tx.glLineId);
          } else {
            _selectedTxIds.add(tx.glLineId);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : null,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedTxIds.add(tx.glLineId);
                    } else {
                      _selectedTxIds.remove(tx.glLineId);
                    }
                  });
                },
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                DateFormat('yyyy-MM-dd').format(tx.date),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                tx.description,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                tx.reference,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${tx.amount.toStringAsFixed(2)} ر.س',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: tx.amount >= Decimal.zero ? Colors.green : Colors.red,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'ملاحظات التسوية...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _selectedTxIds.isEmpty ? null : _reconcileSelected,
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('تسوية المحدد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _autoReconcile,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('تسوية تلقائية'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _reconcileAll,
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('تسوية الكل'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTransactions() async {
    if (_selectedAccountId == null) return;

    setState(() {
      _isLoading = true;
      _selectedTxIds.clear();
      _selectAll = false;
    });

    try {
      final transactions =
          await _reconciliationService.getUnmatchedTransactions(
        accountId: _selectedAccountId!,
        fromDate: _fromDate,
        toDate: _toDate,
      );

      final balance =
          await _db.accountingDao.getAccountBalance(_selectedAccountId!);

      if (mounted) {
        setState(() {
          _transactions = transactions;
          _bookBalance = balance.toDouble();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل المعاملات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reconcileSelected() async {
    if (_selectedAccountId == null || _selectedTxIds.isEmpty) return;

    try {
      for (final txId in _selectedTxIds) {
        final tx = _transactions.firstWhere((t) => t.glLineId == txId);
        await _reconciliationService.reconcileTransaction(
          accountId: _selectedAccountId!,
          glLineId: tx.glLineId,
          entryId: tx.entryId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تسوية ${_selectedTxIds.length} معاملة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadTransactions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التسوية: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _autoReconcile() async {
    if (_selectedAccountId == null) return;

    final tolerance =
        Decimal.tryParse(_toleranceController.text) ?? Decimal.zero;

    try {
      final bankLines = _transactions.map((tx) => BankStatementLine(
        date: tx.date,
        description: tx.description,
        amount: tx.amount,
        reference: tx.reference,
      )).toList();

      final matched = await _reconciliationService.autoReconcile(
        accountId: _selectedAccountId!,
        bankLines: bankLines,
        tolerance: tolerance,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تسوية $matched معاملة تلقائياً'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      _loadTransactions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التسوية التلقائية: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reconcileAll() async {
    if (_selectedAccountId == null || _transactions.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسوية الكل'),
        content: Text(
            'هل تريد تسوية جميع ${_transactions.length} معاملة غير مسوّاة؟'),
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

    if (confirmed != true) return;

    try {
      for (final tx in _transactions) {
        await _reconciliationService.reconcileTransaction(
          accountId: _selectedAccountId!,
          glLineId: tx.glLineId,
          entryId: tx.entryId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تسوية جميع ${_transactions.length} معاملة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadTransactions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التسوية: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
