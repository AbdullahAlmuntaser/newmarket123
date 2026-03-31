import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:drift/drift.dart' as drift;

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
          if (users.isEmpty) {
            return Center(child: Text(l10n.noUsersFound));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.fullName),
                subtitle: Text(user.role),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
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
    String selectedRole = user?.role ?? 'user';

    showDialog(
      context: context,
      builder: (context) {
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
                    hintText: isEditing ? l10n.leaveEmptyToKeep : null,
                  ),
                  obscureText: true,
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  items: ['admin', 'user']
                      .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      selectedRole = value;
                    }
                  },
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
                    final updatedUser = user.copyWith(
                      fullName: fullName,
                      username: username,
                      role: selectedRole,
                      password: password.isNotEmpty ? password : user.password,
                    );
                    await db.usersDao.updateUser(updatedUser);
                  } else {
                    final newUser = UsersCompanion(
                      fullName: drift.Value(fullName),
                      username: drift.Value(username),
                      password: drift.Value(password), // Passwords should be hashed
                      role: drift.Value(selectedRole),
                    );
                    await db.usersDao.addUser(newUser);
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
  }

  void _deleteUser(BuildContext context, User user) async {
    final l10n = AppLocalizations.of(context)!;
    final db = context.read<AppDatabase>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteUser),
        content: Text(l10n.confirmDeleteUser(user.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await db.usersDao.deleteUser(user);
    }
  }
}
