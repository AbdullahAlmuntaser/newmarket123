import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;

class ShiftsPage extends StatelessWidget {
  const ShiftsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الورديات')),
      body: StreamBuilder<List<Shift>>(
        stream: db.select(db.shifts).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final shift = snapshot.data![index];
              return ListTile(
                title: Text('وردية: ${shift.startTime.toString().split(' ')[0]}'),
                subtitle: Text('الحالة: ${shift.isOpen ? "مفتوحة" : "مغلقة"}'),
                trailing: shift.isOpen
                    ? ElevatedButton(onPressed: () => _closeShift(context, db, shift), child: const Text('إغلاق'))
                    : null,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openShift(context, db),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openShift(BuildContext context, AppDatabase db) async {
    await db.into(db.shifts).insert(ShiftsCompanion.insert(
      userId: 'current_user_id', // يجب استبداله بـ ID المستخدم الفعلي
      startTime: drift.Value(DateTime.now()),
      isOpen: const drift.Value(true),
    ));
  }

  Future<void> _closeShift(BuildContext context, AppDatabase db, Shift shift) async {
    await (db.update(db.shifts)..where((s) => s.id.equals(shift.id))).write(
      ShiftsCompanion(
        endTime: drift.Value(DateTime.now()),
        isOpen: const drift.Value(false),
      ),
    );
  }
}
