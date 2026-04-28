import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:bcrypt/bcrypt.dart';

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.staffManagement)),
      body: StreamBuilder<List<User>>(
        stream: db.usersDao.watchAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? [];
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.fullName),
                subtitle: Text(user.role),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteUser(context, user),
                ),
                onTap: () => _showAddEditUserDialog(context, user: user),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditUserDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEditUserDialog(BuildContext context, {User? user}) {
    final l10n = AppLocalizations.of(context)!;
    final db = context.read<AppDatabase>();
    final isEditing = user != null;

    final nameController = TextEditingController(text: user?.fullName ?? '');
    final usernameController = TextEditingController(text: user?.username ?? '');
    final passwordController = TextEditingController();
    String selectedRole = user?.role ?? 'cashier';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? l10n.editUser : l10n.addUser),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: l10n.fullName),
                    ),
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(labelText: l10n.username),
                    ),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        hintText: isEditing ? 'اتركه فارغاً للاحتفاظ بكلمة المرور' : null,
                      ),
                      obscureText: true,
                    ),
                    DropdownButtonFormField<String>(
                      key: ValueKey(selectedRole), // Unique key forces rebuild
                      value: selectedRole,
                      onChanged: (value) => setState(() => selectedRole = value!),
                      items: ['admin', 'manager', 'cashier']
                          .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                          .toList(),
                      decoration: InputDecoration(labelText: l10n.role),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final fullName = nameController.text;
                    final username = usernameController.text;
                    final password = passwordController.text;

                    if (fullName.isNotEmpty && username.isNotEmpty) {
                      if (isEditing) {
                        String finalPassword = user.password;
                        if (password.isNotEmpty) {
                          finalPassword = BCrypt.hashpw(password, BCrypt.gensalt());
                        }
                        await db.usersDao.updateUser(user.copyWith(
                          fullName: fullName,
                          username: username,
                          role: selectedRole,
                          password: finalPassword,
                        ));
                      } else {
                        if (password.isEmpty) return;
                        await db.usersDao.addUser(UsersCompanion.insert(
                          fullName: fullName,
                          username: username,
                          password: BCrypt.hashpw(password, BCrypt.gensalt()),
                          role: selectedRole,
                        ));
                      }
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteUser(BuildContext context, User user) async {
    final db = context.read<AppDatabase>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مستخدم'),
        content: Text('هل أنت متأكد من حذف ${user.fullName}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) await db.usersDao.deleteUser(user);
  }
}
