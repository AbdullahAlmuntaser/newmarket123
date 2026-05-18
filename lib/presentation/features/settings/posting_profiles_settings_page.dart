import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';

class PostingProfilesSettingsPage extends StatelessWidget {
  const PostingProfilesSettingsPage({super.key});

  static const Map<String, String> _operationTypes = {
    'SALE': 'بيع',
    'PURCHASE': 'شراء',
    'RETURN': 'مرتجع',
    'PAYMENT': 'سداد',
    'EXPENSE': 'مصروف',
    'INVENTORY': 'مخزون',
  };

  static const Map<String, String> _accountTypes = {
    'CASH': 'نقد/بنك',
    'RECEIVABLE': 'ذمم مدينة',
    'PAYABLE': 'ذمم دائنة',
    'REVENUE': 'إيراد',
    'COGS': 'تكلفة مبيعات',
    'INVENTORY': 'مخزون',
    'EXPENSE': 'مصروف',
    'DISCOUNT': 'خصم',
    'TAX': 'ضريبة',
  };

  static const Map<String, String> _sides = {
    'DEBIT': 'مدين',
    'CREDIT': 'دائن',
  };

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات القيود المحاسبية')),
      body: StreamBuilder<List<PostingProfile>>(
        stream: db.accountingDao.watchPostingProfiles(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profiles = snapshot.data!;

          return FutureBuilder<List<GLAccount>>(
            future: db.accountingDao.getAllAccounts(),
            builder: (context, accountSnapshot) {
              if (!accountSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final accounts = accountSnapshot.data!;
              final accountMap = {for (var a in accounts) a.id: a};

              return ListView.builder(
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  final account = accountMap[profile.accountId];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      title: Text(
                        '${_operationTypes[profile.operationType] ?? profile.operationType} - '
                        '${_accountTypes[profile.accountType] ?? profile.accountType}',
                      ),
                      subtitle: Text(
                        'الجانب: ${_sides[profile.side] ?? profile.side} | '
                        'الحساب: ${account?.name ?? 'غير محدد'}',
                      ),
                      onTap: () => _showAddProfileDialog(
                        context,
                        db,
                        accounts,
                        profile: profile,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            db.accountingDao.deletePostingProfile(profile.id),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final accounts = await db.accountingDao.getAllAccounts();
          if (context.mounted) _showAddProfileDialog(context, db, accounts);
        },
      ),
    );
  }

  Future<void> _showAddProfileDialog(
    BuildContext context,
    AppDatabase db,
    List<GLAccount> accounts, {
    PostingProfile? profile,
  }) async {
    String? selectedOperationType = _operationTypes.containsKey(
      profile?.operationType,
    )
        ? profile!.operationType
        : null;
    String? selectedAccountType = _accountTypes.containsKey(profile?.accountType)
        ? profile!.accountType
        : null;
    String side = _sides.containsKey(profile?.side) ? profile!.side : 'DEBIT';
    final postingAccounts =
        accounts.where((account) => !account.isHeader).toList();
    String? selectedAccountId = postingAccounts.any(
      (account) => account.id == profile?.accountId,
    )
        ? profile!.accountId
        : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            profile == null ? 'إضافة قيد ترحيل جديد' : 'تعديل قيد الترحيل',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedOperationType,
                  isExpanded: true,
                  items: _operationTypes.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text('${entry.value} (${entry.key})'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedOperationType = value),
                  decoration: const InputDecoration(labelText: 'نوع العملية'),
                ),
                DropdownButtonFormField<String>(
                  value: selectedAccountType,
                  isExpanded: true,
                  items: _accountTypes.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text('${entry.value} (${entry.key})'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedAccountType = value),
                  decoration: const InputDecoration(labelText: 'نوع الحساب'),
                ),
                DropdownButtonFormField<String>(
                  value: selectedAccountId,
                  isExpanded: true,
                  items: postingAccounts
                      .map(
                        (account) => DropdownMenuItem(
                          value: account.id,
                          child: Text('${account.code} - ${account.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedAccountId = value),
                  decoration: const InputDecoration(
                    labelText: 'الحساب المحاسبي',
                    helperText: 'لا يمكن اختيار حساب رئيسي',
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: side,
                  isExpanded: true,
                  items: _sides.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text('${entry.value} (${entry.key})'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => side = value!),
                  decoration: const InputDecoration(labelText: 'الجانب'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedOperationType == null ||
                    selectedAccountType == null) {
                  AppSnackBar.warning(context, 'نوع العملية ونوع الحساب مطلوبان');
                  return;
                }
                if (selectedAccountId == null) {
                  AppSnackBar.warning(
                    context,
                    'يرجى اختيار حساب تفصيلي للترحيل',
                  );
                  return;
                }

                try {
                  if (profile == null) {
                    await db.accountingDao.createPostingProfile(
                      PostingProfilesCompanion.insert(
                        operationType: selectedOperationType!,
                        accountType: selectedAccountType!,
                        accountId: drift.Value(selectedAccountId),
                        side: side,
                      ),
                    );
                  } else {
                    await db.accountingDao.updatePostingProfile(
                      profile.copyWith(
                        operationType: selectedOperationType!,
                        accountType: selectedAccountType!,
                        accountId: drift.Value(selectedAccountId),
                        side: side,
                      ),
                    );
                  }
                  if (context.mounted) {
                    AppSnackBar.success(context, 'تم حفظ إعداد الترحيل بنجاح');
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppSnackBar.error(context, 'فشل حفظ إعداد الترحيل: $e');
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
