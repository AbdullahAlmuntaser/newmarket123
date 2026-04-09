import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/presentation/features/hr/hr_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الموظفين')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: provider.employees.length,
              itemBuilder: (context, index) {
                final emp = provider.employees[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(emp.name),
                  subtitle: Text(
                    '${emp.jobTitle ?? 'بدون مسمى'} - راتب: ${emp.basicSalary}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showAddEditDialog(context, provider, emp),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => provider.deleteEmployee(emp.id),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(context, provider, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEditDialog(
    BuildContext context,
    HRProvider provider,
    Employee? employee,
  ) {
    final nameController = TextEditingController(text: employee?.name);
    final codeController = TextEditingController(text: employee?.employeeCode);
    final jobTitleController = TextEditingController(text: employee?.jobTitle);
    final salaryController = TextEditingController(
      text: employee?.basicSalary.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(employee == null ? 'إضافة موظف' : 'تعديل موظف'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'كود الموظف'),
              ),
              TextField(
                controller: jobTitleController,
                decoration: const InputDecoration(labelText: 'المسمى الوظيفي'),
              ),
              TextField(
                controller: salaryController,
                decoration: const InputDecoration(labelText: 'الراتب الأساسي'),
                keyboardType: TextInputType.number,
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
              if (employee == null) {
                provider.addEmployee(
                  EmployeesCompanion.insert(
                    id: Value(const Uuid().v4()),
                    name: nameController.text,
                    employeeCode: codeController.text,
                    jobTitle: Value(jobTitleController.text),
                    basicSalary: Value(
                      double.tryParse(salaryController.text) ?? 0.0,
                    ),
                    isActive: const Value(true),
                  ),
                );
              } else {
                provider.updateEmployee(
                  employee.copyWith(
                    name: nameController.text,
                    employeeCode: codeController.text,
                    jobTitle: Value(jobTitleController.text),
                    basicSalary: double.tryParse(salaryController.text) ?? 0.0,
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
