# 🚀 خطة التنفيذ الفورية - نظام ERP

## المرحلة 1: حرجة (يجب الانتهاء خلال أسبوع)

---

## ✅ المهمة 1: إزالة القيم المزروعة (Hardcoded Values)

### 📍 الملفات المتأثرة:
1. `lib/core/services/sales_service.dart:29`
2. `lib/core/services/inventory_service.dart:248`
3. `lib/core/services/accounting_service.dart` (عدة أماكن)
4. `lib/core/services/purchase_service.dart`

### 🔧 الحل:

**خطوة 1:** إنشاء ملف الإعدادات الجديد

```dart
// lib/core/config/app_config.dart

class AppConfig {
  static String? _currentBranchId;
  static String? _currentWarehouseId;
  static double _defaultTaxRate = 0.15;
  
  // Getters
  static String get currentBranchId => _currentBranchId ?? 'BR001';
  static String get currentWarehouseId => _currentWarehouseId ?? 'WH001';
  static double get defaultTaxRate => _defaultTaxRate;
  
  // Setters
  static Future<void> setBranchId(String branchId) async {
    _currentBranchId = branchId;
    await _saveToPreferences();
  }
  
  static Future<void> setWarehouseId(String warehouseId) async {
    _currentWarehouseId = warehouseId;
    await _saveToPreferences();
  }
  
  static Future<void> setTaxRate(double rate) async {
    _defaultTaxRate = rate;
    await _saveToPreferences();
  }
  
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentBranchId = prefs.getString('branch_id');
    _currentWarehouseId = prefs.getString('warehouse_id');
    _defaultTaxRate = prefs.getDouble('tax_rate') ?? 0.15;
  }
  
  static Future<void> _saveToPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('branch_id', _currentBranchId ?? 'BR001');
    await prefs.setString('warehouse_id', _currentWarehouseId ?? 'WH001');
    await prefs.setDouble('tax_rate', _defaultTaxRate);
  }
}
```

**خطوة 2:** تحديث الخدمات

```dart
// قبل:
warehouseId: "MAIN_WAREHOUSE"

// بعد:
warehouseId: AppConfig.currentWarehouseId
```

**خطوة 3:** استدعاء التهيئة في main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.init();  // ✅ إضافة هذا
  runApp(const MyApp());
}
```

**الوقت المتوقع:** 2-3 ساعات

---

## ✅ المهمة 2: تطبيق RBAC الحقيقي

### 📍 الملفات المتأثرة:
- جميع خدمات الأعمال
- جميع صفحات الـ UI

### 🔧 الحل:

**خطوة 1:** إنشاء خدمة الصلاحيات

```dart
// lib/core/services/permission_service.dart

enum UserRole { admin, manager, cashier, supervisor, accountant }

class PermissionService {
  final UserRepository userRepository;
  
  PermissionService(this.userRepository);
  
  // Check permission
  Future<bool> hasPermission(String userId, String permission) async {
    final user = await userRepository.getUserById(userId);
    return user?.permissions.contains(permission) ?? false;
  }
  
  // Create sale
  Future<bool> canCreateSale(String userId) async {
    return hasPermission(userId, 'create_sale');
  }
  
  // Delete invoice
  Future<bool> canDeleteInvoice(String userId) async {
    return hasPermission(userId, 'delete_invoice');
  }
  
  // Create purchase
  Future<bool> canCreatePurchase(String userId) async {
    return hasPermission(userId, 'create_purchase');
  }
  
  // Edit accounting entries
  Future<bool> canEditAccounting(String userId) async {
    return hasPermission(userId, 'edit_accounting');
  }
  
  // Close period
  Future<bool> canClosePeriod(String userId) async {
    return hasPermission(userId, 'close_period');
  }
  
  // And more...
}
```

**خطوة 2:** تطبيق التحقق في الخدمات

```dart
// في sales_service.dart
Future<Sale> createSale(Sale sale, String userId) async {
  if (!await permissionService.canCreateSale(userId)) {
    throw UnauthorizedException('ليس لديك صلاحية إنشاء مبيعة');
  }
  // ... باقي الكود
}
```

**خطوة 3:** تطبيق التحقق في الواجهات

```dart
// في sales_page.dart
onPressed: () async {
  if (!await permissionService.canCreateSale(currentUser.id)) {
    showErrorSnackBar('ليس لديك صلاحية');
    return;
  }
  // ... باقي الكود
}
```

**الوقت المتوقع:** 4-5 ساعات

---

## ✅ المهمة 3: تحسين معالجة الأخطاء

### 📍 الملفات المتأثرة:
- `accounting_service.dart`
- `sales_service.dart`
- `purchase_service.dart`
- `inventory_service.dart`

### 🔧 الحل:

**خطوة 1:** إنشاء فئات الأخطاء المخصصة

```dart
// lib/core/errors/exceptions.dart

class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
  
  @override
  String toString() => 'Database Error: $message';
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  
  @override
  String toString() => 'Validation Error: $message';
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
  
  @override
  String toString() => 'Unauthorized: $message';
}

class InsufficientStockException implements Exception {
  final String productName;
  final double required;
  final double available;
  
  InsufficientStockException({
    required this.productName,
    required this.required,
    required this.available,
  });
  
  @override
  String toString() => 
    'Insufficient Stock: $productName (Required: $required, Available: $available)';
}
```

**خطوة 2:** تطبيق معالجة الأخطاء

```dart
// في sales_service.dart

Future<Sale> createSale(Sale sale) async {
  try {
    // التحقق من صحة البيانات
    if (sale.items.isEmpty) {
      throw ValidationException('يجب أن تحتوي المبيعة على عناصر');
    }
    
    // التحقق من المخزون
    for (var item in sale.items) {
      final stock = await inventoryRepository.getStock(item.productId);
      if (stock < item.quantity) {
        throw InsufficientStockException(
          productName: item.productName,
          required: item.quantity,
          available: stock,
        );
      }
    }
    
    // إنشاء المبيعة
    final result = await saleRepository.create(sale);
    return result;
    
  } on ValidationException catch (e) {
    print('Validation Error: $e');
    rethrow;
  } on InsufficientStockException catch (e) {
    print('Stock Error: $e');
    rethrow;
  } on DatabaseException catch (e) {
    print('Database Error: $e');
    throw Exception('خطأ في قاعدة البيانات');
  } on Exception catch (e) {
    print('Unexpected Error: $e');
    throw Exception('حدث خطأ غير متوقع');
  }
}
```

**خطوة 3:** معالجة الأخطاء في الواجهات

```dart
// في pos_page.dart

try {
  await saleService.createSale(sale);
  showSuccessSnackBar('تم إنشاء المبيعة بنجاح');
} on ValidationException catch (e) {
  showErrorSnackBar('خطأ في البيانات: ${e.message}');
} on InsufficientStockException catch (e) {
  showErrorSnackBar('مخزون غير كافي: ${e.productName}');
} on Exception catch (e) {
  showErrorSnackBar('خطأ: $e');
}
```

**الوقت المتوقع:** 2-3 ساعات

---

## ✅ المهمة 4: إضافة جدول AppSettings

### 🔧 الحل:

**خطوة 1:** إضافة الجدول إلى قاعدة البيانات

```dart
// في app_database.dart

@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => 
    dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {key};
}
```

**خطوة 2:** إنشاء DAO للجدول

```dart
// في app_database.dart - داخل فئة AppDatabase

@DriftAccessor(tables: [AppSettings])
class AppSettingsDao extends DatabaseAccessor<AppDatabase> {
  AppSettingsDao(AppDatabase db) : super(db);
  
  Future<void> setSetting(String key, String value, {String? description}) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion(
        key: Value(key),
        value: Value(value),
        description: description != null ? Value(description) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
  
  Future<String?> getSetting(String key) async {
    final result = await (select(appSettings)
      ..where((tbl) => tbl.key.equals(key)))
      .singleOrNull();
    return result?.value;
  }
  
  Future<List<AppSetting>> getAllSettings() async {
    return select(appSettings).get();
  }
  
  Future<void> deleteSetting(String key) async {
    await (delete(appSettings)..where((tbl) => tbl.key.equals(key))).go();
  }
}
```

**الوقت المتوقع:** 1 ساعة

---

## 📋 قائمة المراجعة - المرحلة 1

```
[ ] 1. إنشاء app_config.dart
[ ] 2. تحديث جميع الخدمات لاستخدام AppConfig
[ ] 3. إضافة AppConfig.init() في main.dart
[ ] 4. اختبار المرحلة 1

[ ] 5. إنشاء permission_service.dart
[ ] 6. تحديث جميع الخدمات للتحقق من الصلاحيات
[ ] 7. تحديث جميع الواجهات للتحقق من الصلاحيات
[ ] 8. اختبار الصلاحيات

[ ] 9. إنشاء classes للأخطاء المخصصة
[ ] 10. تطبيق معالجة الأخطاء في الخدمات
[ ] 11. تطبيق معالجة الأخطاء في الواجهات
[ ] 12. اختبار معالجة الأخطاء

[ ] 13. إضافة جدول AppSettings
[ ] 14. إنشاء AppSettingsDao
[ ] 15. ترقية إصدار قاعدة البيانات
[ ] 16. اختبار AppSettings

[ ] 17. اختبارات شاملة على جميع التغييرات
[ ] 18. مراجعة الكود (Code Review)
[ ] 19. دمج إلى main branch
[ ] 20. نشر للاختبار
```

---

## 🧪 اختبارات سريعة

### 1. اختبار AppConfig

```dart
void main() {
  test('AppConfig should save and load settings', () async {
    await AppConfig.init();
    
    await AppConfig.setBranchId('BR002');
    expect(AppConfig.currentBranchId, 'BR002');
    
    await AppConfig.setWarehouseId('WH002');
    expect(AppConfig.currentWarehouseId, 'WH002');
    
    await AppConfig.setTaxRate(0.20);
    expect(AppConfig.defaultTaxRate, 0.20);
  });
}
```

### 2. اختبار RBAC

```dart
void main() {
  test('Permission service should check permissions correctly', () async {
    final permService = PermissionService(mockUserRepo);
    
    expect(await permService.canCreateSale('user1'), true);
    expect(await permService.canDeleteInvoice('user1'), false);
  });
}
```

### 3. اختبار معالجة الأخطاء

```dart
void main() {
  test('Should throw ValidationException for empty items', () async {
    final salesService = SalesService(/* ... */);
    
    expect(
      () => salesService.createSale(Sale(items: [])),
      throwsA(isA<ValidationException>()),
    );
  });
}
```

---

## ⏱️ الجدول الزمني

| اليوم | المهام | الحالة |
|------|--------|--------|
| **اليوم 1** | المهمة 1 (AppConfig) | ⏳ |
| **اليوم 2** | المهمة 2 (RBAC) | ⏳ |
| **اليوم 3** | المهمة 3 (Error Handling) | ⏳ |
| **اليوم 4** | المهمة 4 (AppSettings) | ⏳ |
| **اليوم 5** | الاختبارات والمراجعة | ⏳ |

---

## 📞 نقاط المساعدة

في حالة الحاجة للمساعدة، يمكن الرجوع إلى:

1. **التقارير الموجودة:**
   - `ANALYSIS_REPORT.md` - تحليل شامل
   - `audit_report.md` - تقرير تدقيق
   - `EXECUTIVE_AUDIT_REPORT_AR.md` - التقرير التنفيذي

2. **الملفات المرجعية:**
   - `DEVELOPMENT_GUIDE.md` - دليل التطوير
   - `IMPROVEMENTS_REPORT.md` - التحسينات السابقة

3. **التواصل:**
   - يمكن طلب توضيحات في أي وقت
   - جميع الملفات موثقة بشكل واضح

---

**النسخة:** 1.0
**التاريخ:** May 6, 2026
**الحالة:** جاهز للتنفيذ

