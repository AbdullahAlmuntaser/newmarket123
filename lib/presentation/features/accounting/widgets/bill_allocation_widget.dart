import 'package:flutter/material.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/injection_container.dart';

class BillAllocationWidget extends StatefulWidget {
  final String customerId;
  final double totalPaymentAmount;
  final Function(List<Allocation>) onAllocationChanged;

  const BillAllocationWidget({
    super.key,
    required this.customerId,
    required this.totalPaymentAmount,
    required this.onAllocationChanged,
  });

  @override
  State<BillAllocationWidget> createState() => _BillAllocationWidgetState();
}

class _BillAllocationWidgetState extends State<BillAllocationWidget> {
  List<SaleWithBalance> _outstandingSales = [];
  Map<String, double> _allocations = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOutstandingSales();
  }

  Future<void> _loadOutstandingSales() async {
    final engine = sl<TransactionEngine>();
    final sales = await engine.getOutstandingSales(widget.customerId);
    setState(() {
      _outstandingSales = sales;
      _isLoading = false;
    });
  }

  double get _totalAllocated =>
      _allocations.values.fold(0, (sum, val) => sum + val);
  double get _remainingAmount => widget.totalPaymentAmount - _totalAllocated;

  void _updateAllocation(String saleId, double amount, double maxBalance) {
    if (amount > maxBalance) amount = maxBalance;

    // Ensure we don't allocate more than the total payment
    final currentOtherAllocations =
        _totalAllocated - (_allocations[saleId] ?? 0);
    if (amount + currentOtherAllocations > widget.totalPaymentAmount) {
      amount = widget.totalPaymentAmount - currentOtherAllocations;
    }

    setState(() {
      if (amount <= 0) {
        _allocations.remove(saleId);
      } else {
        _allocations[saleId] = amount;
      }
    });

    widget.onAllocationChanged(
      _allocations.entries
          .map((e) => Allocation(saleId: e.key, amount: e.value))
          .toList(),
    );
  }

  void _autoAllocate() {
    double remaining = widget.totalPaymentAmount;
    Map<String, double> newAllocations = {};

    for (var saleWithBalance in _outstandingSales) {
      if (remaining <= 0) break;

      double toAllocate = remaining > saleWithBalance.balance
          ? saleWithBalance.balance
          : remaining;
      newAllocations[saleWithBalance.sale.id] = toAllocate;
      remaining -= toAllocate;
    }

    setState(() {
      _allocations = newAllocations;
    });

    widget.onAllocationChanged(
      _allocations.entries
          .map((e) => Allocation(saleId: e.key, amount: e.value))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_outstandingSales.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('لا توجد فواتير آجلة مستحقة لهذا العميل.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'توزيع المبلغ على الفواتير',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _autoAllocate,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('توزيع آلي (الأقدم أولاً)'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _remainingAmount < 0 ? Colors.red[50] : Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المتبقي للتوزيع: ${_remainingAmount.toStringAsFixed(2)}'),
              Text('تم توزيع: ${_totalAllocated.toStringAsFixed(2)}'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _outstandingSales.length,
          itemBuilder: (context, index) {
            final saleWithBalance = _outstandingSales[index];
            final sale = saleWithBalance.sale;
            final isAllocated = _allocations.containsKey(sale.id);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                    'فاتورة #${sale.id.substring(0, 8)} - ${sale.createdAt.toString().split(' ')[0]}'),
                subtitle: Text(
                    'الإجمالي: ${sale.total} | المتبقي: ${saleWithBalance.balance}'),
                trailing: SizedBox(
                  width: 120,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0.00',
                      suffixIcon: isAllocated
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => _updateAllocation(
                                  sale.id, 0, saleWithBalance.balance),
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      final amount = double.tryParse(val) ?? 0;
                      _updateAllocation(
                          sale.id, amount, saleWithBalance.balance);
                    },
                    controller: TextEditingController(
                      text: isAllocated
                          ? _allocations[sale.id]!.toStringAsFixed(2)
                          : '',
                    )..selection = TextSelection.fromPosition(
                        TextPosition(
                            offset: isAllocated
                                ? _allocations[sale.id]!
                                    .toStringAsFixed(2)
                                    .length
                                : 0),
                      ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class Allocation {
  final String saleId;
  final double amount;
  Allocation({required this.saleId, required this.amount});
}
