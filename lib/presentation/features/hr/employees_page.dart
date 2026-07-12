import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/presentation/features/hr/hr_provider.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/money_form_field.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HRProvider>().loadEmployees();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HRProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الموظفين'), elevation: 0),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.employees.length,
              itemBuilder: (context, index) {
                final emp = provider.employees[index];
                return _buildEmployeeCard(emp, provider, colorScheme);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context, provider, null),
        icon: const Icon(Icons.add),
        label: const Text('إضافة موظف'),
      ),
    );
  }

  Widget _buildEmployeeCard(
    HREmployee emp,
    HRProvider provider,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Text(emp.name[0],
              style: TextStyle(color: colorScheme.onPrimaryContainer)),
        ),
        title:
            Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المنصب: ${emp.position ?? 'غير محدد'}'),
            Text('الراتب: ${emp.basicSalary.toStringAsFixed(2)}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'edit') {
              _showAddEditDialog(context, provider, emp);
            } else if (val == 'delete') {
              _confirmDelete(context, provider, emp);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('تعديل')),
            const PopupMenuItem(value: 'delete', child: Text('حذف')),
          ],
        ),
      ),
    );
  }

  void _showAddEditDialog(
    BuildContext context,
    HRProvider provider,
    HREmployee? emp,
  ) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: emp?.name);
    final codeController = TextEditingController(text: emp?.code);
    final positionController = TextEditingController(text: emp?.position);
    final salaryController =
        TextEditingController(text: emp?.basicSalary.toString());
    final joinDateController = TextEditingController(
        text: emp?.hireDate.toIso8601String().substring(0, 10));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(emp == null ? 'إضافة موظف' : 'تعديل موظف'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'الاسم مطلوب';
                    if (v.trim().length < 2) return 'الاسم يجب أن يكون على الأقل حرفين';
                    return null;
                  },
                ),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'كود الموظف'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'الكود مطلوب';
                    if (v.trim().length < 2) return 'الكود يجب أن يكون على الأقل حرفين';
                    return null;
                  },
                ),
                TextField(
                  controller: positionController,
                  decoration: const InputDecoration(labelText: 'المنصب'),
                ),
                MoneyFormField(
                  controller: salaryController,
                  label: 'الراتب الأساسي',
                ),
                TextField(
                  controller: joinDateController,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الانضمام',
                    hintText: 'YYYY-MM-DD',
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      joinDateController.text =
                          date.toIso8601String().substring(0, 10);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final salary = Decimal.tryParse(salaryController.text) ?? Decimal.zero;
              final hireDate =
                  DateTime.tryParse(joinDateController.text) ?? DateTime.now();

              try {
                if (emp == null) {
                  await provider.addEmployee(
                    HREmployeesCompanion.insert(
                      name: nameController.text.trim(),
                      code: codeController.text.trim(),
                      position: Value(positionController.text.trim()),
                      basicSalary: salary,
                      hireDate: hireDate,
                    ),
                  );
                } else {
                  await provider.updateEmployee(
                    HREmployeesCompanion(
                      id: Value(emp.id),
                      name: Value(nameController.text.trim()),
                      code: Value(codeController.text.trim()),
                      position: Value(positionController.text.trim()),
                      basicSalary: Value(salary),
                      hireDate: Value(hireDate),
                    ),
                  );
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  AppSnackBar.success(
                      context, emp == null ? 'تم إضافة الموظف' : 'تم تعديل الموظف');
                }
              } catch (e) {
                if (context.mounted) {
                  AppSnackBar.error(context, 'خطأ في الحفظ: $e');
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    HRProvider provider,
    HREmployee emp,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الموظف ${emp.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.deleteEmployee(emp.id);
              Navigator.pop(context);
              AppSnackBar.success(context, 'تم حذف الموظف');
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
