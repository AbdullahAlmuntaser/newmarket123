import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart';

class WarehouseManagerPage extends StatelessWidget {
  const WarehouseManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = sl<AppDatabase>();
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة أمين المخزن')),
      body: StreamBuilder<List<Employee>>(
        stream: db.select(db.employees).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final employees = snapshot.data!;
          return ListView.builder(
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final emp = employees[index];
              return ListTile(
                title: Text(emp.name),
                subtitle: Text('الكود: ${emp.employeeCode} | الوظيفة: ${emp.jobTitle ?? 'غير محدد'}'),
                trailing: const Icon(Icons.person),
              );
            },
          );
        },
      ),
    );
  }
}
