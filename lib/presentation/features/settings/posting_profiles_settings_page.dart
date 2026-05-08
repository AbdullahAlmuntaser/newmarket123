import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;

class PostingProfilesSettingsPage extends StatelessWidget {
  const PostingProfilesSettingsPage({super.key});

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
              final accountMap = {for (var a in accounts) a.id: a.name};

              return ListView.builder(
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  final accountName =
                      accountMap[profile.accountId] ?? 'غير محدد';
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      title: Text(
                          '${profile.operationType} - ${profile.accountType}'),
                      subtitle: Text(
                          'الجانب: ${profile.side} | الحساب: $accountName'),
                      onTap: () => _showAddProfileDialog(context, db, accounts,
                          profile: profile),
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
      BuildContext context, AppDatabase db, List<GLAccount> accounts,
      {PostingProfile? profile}) async {
    final operationController =
        TextEditingController(text: profile?.operationType ?? '');
    final accountTypeController =
        TextEditingController(text: profile?.accountType ?? '');
    String side = profile?.side ?? 'DEBIT';
    String? selectedAccountId = profile?.accountId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
              profile == null ? 'إضافة قيد ترحيل جديد' : 'تعديل قيد الترحيل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: operationController,
                    decoration: const InputDecoration(
                        labelText: 'نوع العملية (SALE, PURCHASE)')),
                TextField(
                    controller: accountTypeController,
                    decoration: const InputDecoration(
                        labelText: 'نوع الحساب (REVENUE, CASH)')),
                DropdownButtonFormField<String>(
                  value: selectedAccountId,
                  isExpanded: true,
                  items: accounts
                      .map((a) =>
                          DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedAccountId = v),
                  decoration:
                      const InputDecoration(labelText: 'الحساب المحاسبي'),
                ),
                DropdownButtonFormField<String>(
                  value: side,
                  items: ['DEBIT', 'CREDIT']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => side = v!),
                  decoration: const InputDecoration(labelText: 'الجانب'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (profile == null) {
                  db.accountingDao
                      .createPostingProfile(PostingProfilesCompanion.insert(
                    operationType: operationController.text.toUpperCase(),
                    accountType: accountTypeController.text.toUpperCase(),
                    accountId: drift.Value(selectedAccountId),
                    side: side,
                  ));
                } else {
                  db.accountingDao.updatePostingProfile(profile.copyWith(
                    operationType: operationController.text.toUpperCase(),
                    accountType: accountTypeController.text.toUpperCase(),
                    accountId: drift.Value(selectedAccountId),
                    side: side,
                  ));
                }
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
