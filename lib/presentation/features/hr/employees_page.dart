import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/hr/hr_provider.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';
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
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    emp.name[0].toUpperCase(),
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        emp.position ?? 'بدون مسمى وظيفي',
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'كود: ${emp.code}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(emp.status == 'active'),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الراتب الأساسي',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      '${emp.basicSalary.toStringAsFixed(2)} ر.س',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.edit),
                      onPressed: () =>
                          _showAddEditDialog(context, provider, emp),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(emp, provider),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? Colors.green : Colors.red).withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isActive ? Colors.green : Colors.red).withAlpha(100),
        ),
      ),
      child: Text(
        isActive ? 'نشط' : 'متوقف',
        style: TextStyle(
          color: isActive ? Colors.green : Colors.red,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _confirmDelete(HREmployee emp, HRProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف موظف'),
        content: Text('هل أنت متأكد من حذف الموظف ${emp.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteEmployee(emp.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog(
    BuildContext context,
    HRProvider provider,
    HREmployee? employee,
  ) {
    final nameController = TextEditingController(text: employee?.name);
    final codeController = TextEditingController(text: employee?.code);
    final jobTitleController = TextEditingController(text: employee?.position);
    final salaryController = TextEditingController(
      text: employee?.basicSalary.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(employee == null ? 'إضافة موظف جديد' : 'تعديل بيانات موظف'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'الاسم الكامل'),
              ),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'كود الموظف'),
              ),
              TextField(
                controller: jobTitleController,
                decoration: const InputDecoration(labelText: 'المسمى الوظيفي'),
              ),
              MoneyFormField(
                controller: salaryController,
                label: 'الراتب الأساسي',
                required: true,
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
            onPressed: () {
              final salary = MoneyFormField.tryParse(salaryController.text);
              if (nameController.text.trim().isEmpty) {
                AppSnackBar.warning(context, 'اسم الموظف مطلوب');
                return;
              }
              if (codeController.text.trim().isEmpty) {
                AppSnackBar.warning(context, 'كود الموظف مطلوب');
                return;
              }
              if (salary == null || salary < 0) {
                AppSnackBar.warning(context, 'يرجى إدخال راتب أساسي صحيح');
                return;
              }
              if (employee == null) {
                provider.addEmployee(
                  HREmployeesCompanion.insert(
                    name: nameController.text.trim(),
                    code: codeController.text.trim(),
                    position: Value(jobTitleController.text.trim()),
                    basicSalary: salary,
                    hireDate: DateTime.now(),
                    status: const Value('active'),
                  ),
                );
              } else {
                provider.updateEmployee(
                  employee.copyWith(
                    name: nameController.text.trim(),
                    code: codeController.text.trim(),
                    position: Value(jobTitleController.text.trim()),
                    basicSalary: salary,
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('حفظ البيانات'),
          ),
        ],
      ),
    );
  }
}
