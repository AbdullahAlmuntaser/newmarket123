import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/transfer_service.dart';
import 'package:supermarket/presentation/widgets/shared/account_selector_widget.dart';
import 'package:intl/intl.dart' as intl;

class TransfersPage extends StatefulWidget {
  const TransfersPage({super.key});

  @override
  State<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends State<TransfersPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _commissionController = TextEditingController();
  final _companyController = TextEditingController();
  final _noteController = TextEditingController();
  
  String? _senderAccountId;
  String? _receiverAccountId;
  String _transferType = 'CASH';

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final transferService = Provider.of<TransferService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('الحوالات المالية')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AccountSelectorWidget(
                          label: 'من حساب',
                          selectedAccountId: _senderAccountId,
                          onSelected: (acc) => setState(() => _senderAccountId = acc?.id),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AccountSelectorWidget(
                          label: 'إلى حساب',
                          selectedAccountId: _receiverAccountId,
                          onSelected: (acc) => setState(() => _receiverAccountId = acc?.id),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _commissionController,
                          decoration: const InputDecoration(labelText: 'العمولة', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _transferType,
                          decoration: const InputDecoration(labelText: 'نوع التحويل', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'CASH', child: Text('نقدي')),
                            DropdownMenuItem(value: 'BANK', child: Text('بنكي')),
                            DropdownMenuItem(value: 'CHECK', child: Text('شيك')),
                          ],
                          onChanged: (v) => setState(() => _transferType = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _companyController,
                          decoration: const InputDecoration(labelText: 'شركة التحويل', border: OutlineInputBorder()),
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
                        if (_senderAccountId == null || _receiverAccountId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(ApiResponseSnackBar(message: 'يرجى اختيار الحسابات', isError: true));
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await transferService.createTransfer(
                            senderAccountId: _senderAccountId!,
                            receiverAccountId: _receiverAccountId!,
                            amount: double.parse(_amountController.text),
                            commission: double.tryParse(_commissionController.text) ?? 0.0,
                            company: _companyController.text,
                            transferType: _transferType,
                            note: _noteController.text,
                          );
                          if (!mounted) return;
                          messenger.showSnackBar(ApiResponseSnackBar(message: 'تم التحويل بنجاح'));
                          _formKey.currentState!.reset();
                          setState(() {
                            _senderAccountId = null;
                            _receiverAccountId = null;
                          });
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(ApiResponseSnackBar(message: 'خطأ: $e', isError: true));
                        }
                      }
                    },
                    child: const Text('تسجيل التحويل'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<FinancialTransfer>>(
              stream: db.transfersDao.watchAllTransfers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final transfers = snapshot.data!;
                return ListView.builder(
                  itemCount: transfers.length,
                  itemBuilder: (context, index) {
                    final t = transfers[index];
                    return ListTile(
                      title: Text('تحويل: ${t.amount}'),
                      subtitle: Text('${intl.DateFormat('yyyy-MM-dd').format(t.date)} - ${t.note ?? ""}'),
                      trailing: Text(t.status),
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
