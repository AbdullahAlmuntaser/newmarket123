import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/services/loyalty_service.dart';

class LoyaltyPage extends StatefulWidget {
  const LoyaltyPage({super.key});

  @override
  State<LoyaltyPage> createState() => _LoyaltyPageState();
}

class _LoyaltyPageState extends State<LoyaltyPage> {
  final _customerController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = true;
  Map<String, int> _balances = const {};
  List<LoyaltyTransaction> _transactions = const [];

  LoyaltyService get _service => context.read<LoyaltyService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _customerController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final balances = await _service.getBalances();
      final transactions = await _service.listTransactions();
      if (mounted) {
        setState(() {
          _balances = balances;
          _transactions = transactions;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل نقاط الولاء: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _awardPoints() async {
    final customerId = _customerController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (customerId.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل معرف العميل والمبلغ بشكل صحيح')),
      );
      return;
    }
    await _service.awardPoints(customerId: customerId, amount: amount);
    _amountController.clear();
    await _loadData();
  }

  Future<void> _redeemPoints() async {
    final customerId = _customerController.text.trim();
    final points = int.tryParse(_amountController.text.trim()) ?? 0;
    if (customerId.isEmpty || points <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل معرف العميل وعدد النقاط بشكل صحيح')),
      );
      return;
    }
    try {
      await _service.redeemPoints(customerId: customerId, points: points);
      _amountController.clear();
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر استبدال النقاط: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نقاط الولاء')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _customerController,
                            decoration: const InputDecoration(
                              labelText: 'معرف العميل',
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'مبلغ البيع أو النقاط',
                              prefixIcon: Icon(Icons.stars),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _awardPoints,
                                icon: const Icon(Icons.add),
                                label: const Text('إضافة نقاط من بيع'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _redeemPoints,
                                icon: const Icon(Icons.redeem),
                                label: const Text('استبدال نقاط'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('الأرصدة', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_balances.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('لا توجد أرصدة نقاط حالياً'),
                      ),
                    )
                  else
                    ..._balances.entries.map(
                      (entry) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.card_giftcard),
                          title: Text('العميل: ${entry.key}'),
                          trailing: Text('${entry.value} نقطة'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('آخر العمليات', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._transactions.take(20).map(
                        (item) => Card(
                          child: ListTile(
                            leading: Icon(
                              item.points >= 0 ? Icons.add_circle : Icons.remove_circle,
                              color: item.points >= 0 ? Colors.green : Colors.orange,
                            ),
                            title: Text('العميل: ${item.customerId}'),
                            subtitle: Text(
                              '${item.reason} • ${DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt)}',
                            ),
                            trailing: Text('${item.points}'),
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}
