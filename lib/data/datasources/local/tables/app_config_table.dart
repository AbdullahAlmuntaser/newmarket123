import 'package:drift/drift.dart';

/// جدول إعدادات التطبيق الديناميكية
/// يستخدم لتخزين القيم التي كانت مزروعة (Hardcoded) سابقاً
@DataClassName('AppConfig')
class AppConfigTable extends Table {
  /// مفتاح الإعداد (مثل: default_warehouse_id, tax_rate)
  TextColumn get key => text()();

  /// قيمة الإعداد
  TextColumn get value => text().nullable()();

  /// وصف الإعداد (اختياري)
  TextColumn get description => text().nullable()();

  /// تاريخ آخر تحديث
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}
