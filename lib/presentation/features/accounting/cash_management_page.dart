import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/cash_management_service.dart';
import 'package:supermarket/presentation/widgets/shared/account_selector_widget.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';
import 'package:supermarket/presentation/widgets/money_form_field.dart';

class CashManagementPage extends StatefulWidget {
  const CashManagementPage({super.key});

  @override
  State<CashManagementPage> createState() => _CashManagementPageState();
}

class _CashManagementPageState extends State<CashManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _categoryController = TextEditingController();
  
  String? _accountId;
  bool _isReceipt = true; // true for Receipt (In), false for Payment (Out)

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final cashService = Provider.of<CashManagementService>(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isReceipt ? 'سند قبض نقدي' : 'سند صرف نقدي')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('قبض (In)'),
                        selected: _isReceipt,
                        onSelected: (v) => setState(() => _isReceipt = true),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('صرف (Out)'),
                        selected: !_isReceipt,
                        onSelected: (v) => setState(() => _isReceipt = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AccountSelectorWidget(
                    label: _isReceipt ? 'الحساب الدائن (المصدر)' : 'الحساب المدين (الجهة)',
                    selectedAccountId: _accountId,
                    onSelected: (acc) => setState(() => _accountId = acc?.id),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: MoneyFormField(
                          controller: _amountController,
                          label: 'المبلغ',
                          required: true,
                          allowZero: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(labelText: 'التصنيف (مثلاً: إيجار، رواتب)', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        if (_accountId == null) {
                          AppSnackBar.warning(context, 'يرجى اختيار الحساب');
                          return;
                        }
                        try {
                          if (_isReceipt) {
                            await cashService.createCashReceipt(
                              amount: MoneyFormField.valueOf(_amountController),
                              category: _categoryController.text,
                              accountId: _accountId!,
                              note: _noteController.text,
                            );
                          } else {
                            await cashService.createCashPayment(
                              amount: MoneyFormField.valueOf(_amountController),
                              category: _categoryController.text,
                              accountId: _accountId!,
                              note: _noteController.text,
                            );
                          }
                          if (!mounted) return;
                          AppSnackBar.success(context, 'تم تسجيل السند بنجاح');
                          _formKey.currentState!.reset();
                          setState(() => _accountId = null);
                        } catch (e) {
                          if (!mounted) return;
                          AppSnackBar.error(context, 'خطأ: $e');
                        }
                      }
                    },
                    child: Text(_isReceipt ? 'حفظ سند القبض' : 'حفظ سند الصرف'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<CashboxTransaction>>(
              stream: db.cashboxDao.watchAllTransactions(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final transactions = snapshot.data!;
                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    return ListTile(
                      leading: Icon(t.type == 'IN' ? Icons.arrow_downward : Icons.arrow_upward, color: t.type == 'IN' ? Colors.green : Colors.red),
                      title: Text('${t.category}: ${t.amount}'),
                      subtitle: Text('${intl.DateFormat('yyyy-MM-dd').format(t.createdAt)} - ${t.note ?? ""}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ApiResponseSnackBar extends SnackBar {
  ApiResponseSnackBar({super.key, required String message, bool isError = false})
      : super(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        );
}
