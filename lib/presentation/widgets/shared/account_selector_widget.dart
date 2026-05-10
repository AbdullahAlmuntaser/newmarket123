import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class AccountSelectorWidget extends StatelessWidget {
  final String? selectedAccountId;
  final Function(GLAccount?) onSelected;
  final String label;

  const AccountSelectorWidget({
    super.key,
    this.selectedAccountId,
    required this.onSelected,
    this.label = 'اختر الحساب',
  });

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);

    return FutureBuilder<List<GLAccount>>(
      future: db.accountingDao.getAllAccounts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final accounts = snapshot.data!.where((a) => !a.isHeader).toList();

        return DropdownButtonFormField<String>(
          value: selectedAccountId,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          items: accounts.map((account) {
            return DropdownMenuItem(
              value: account.id,
              child: Text('${account.code} - ${account.name}'),
            );
          }).toList(),
          onChanged: (value) {
            final selected = accounts.firstWhere((a) => a.id == value);
            onSelected(selected);
          },
        );
      },
    );
  }
}
