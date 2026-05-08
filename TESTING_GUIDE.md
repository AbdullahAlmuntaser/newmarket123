# نظام الاختبارات - Testing Guide

## نظرة عامة
هذا المشروع يستخدم Flutter Test Framework لكتابة وتشغيل الاختبارات.

## هيكل الاختبارات

```
test/
├── logic/           # اختبارات المنطق والأدوات
├── services/        # اختبارات الخدمات
├── unit/           # اختبارات الوحدات
├── integration/     # اختبارات التكامل
├── widgets/        # اختبارات الويدجتس
└── repositories/   # اختبارات المستودعات
```

## أوامر التشغيل

### تشغيل جميع الاختبارات
```bash
flutter test
```

### تشغيل اختبارات المنطق
```bash
flutter test test/logic
```

### تشغيل اختبارات الخدمات
```bash
flutter test test/services
```

### تشغيل اختبارات الوحدات
```bash
flutter test test/unit
```

### تشغيل اختبارات التكامل
```bash
flutter test test/integration
```

### تشغيل ملف محدد
```bash
flutter test test/logic/calculation_test.dart
```

### تشغيل اختبار محدد
```bash
flutter test test/logic/calculation_test.dart --name "TaxCalculator"
```

### تشغيل مع Coverage Report
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### تشغيل الاختبارات المتزامنة
```bash
flutter test --concurrency=1
```

## ملفات الاختبار الموجودة

### اختبارات المنطق (logic/)
- `auth_test.dart` - اختبارات المصادقة والأذونات
- `calculation_test.dart` - اختبارات الحسابات والضرائب والخصومات
- `enums_test.dart` - اختبارات التعدادات
- `unit_conversion_test.dart` - اختبارات تحويل الوحدات
- `validators_test.dart` - اختبارات المدققات

### اختبارات الخدمات (services/)
- `accounting_service_test.dart` - اختبارات الخدمة المحاسبية
- `app_config_service_test.dart` - اختبارات إعدادات التطبيق
- `inventory_costing_test.dart` - اختبارات تقييم المخزون
- `pricing_service_test.dart` - اختبارات التسعير

### اختبارات الوحدات (unit/)
- `access_control_test.dart` - اختبارات التحكم بالوصول
- `accounting_service_test.dart` - اختبارات المحاسبة
- `analytics_service_test.dart` - اختبارات التحليلات
- `inventory_service_test.dart` - اختبارات المخزون

### اختبارات التكامل (integration/)
- `database_helper_test.dart` - اختبارات مساعدة قاعدة البيانات
- `erp_flow_test.dart` - اختبارات تدفق نظام تخطيط الموارد
- `sales_flow_test.dart` - اختبارات تدفق المبيعات
- `sales_workflow_test.dart` - اختبارات دورة عمل المبيعات

## كتابة اختبارات جديدة

### هيكل الاختبار الأساسي
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('اسم المجموعة', () {
    test('وصف الاختبار', () {
      // Arrange
      final value = 10;

      // Act
      final result = value * 2;

      // Assert
      expect(result, equals(20));
    });
  });
}
```

### اختبارات Async
```dart
test('async test', () async {
  final result = await myAsyncFunction();
  expect(result, equals(expected));
});
```

### اختبارات Exceptions
```dart
test('throws exception', () {
  expect(() => myFunction(), throwsException);
});
```

## Dependencies المستخدمة للاختبارات

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mocktail: ^1.0.4
  mockito: ^5.4.4
  patrol: ^3.11.1
  golden_toolkit: ^0.15.0
```

## نصائح للاختبار الجيد

1. **AAA Pattern**: Arrange, Act, Assert
2. ** Descriptive Names**: اكتب وصف واضح للاختبار
3. **Single Responsibility**: كل اختبار يختبر شيئاً واحداً
4. **Edge Cases**: اختبر الحالات الحدية
5. **Mock External Dependencies**: استخدم Mock للتبعيات الخارجية
6. **Keep Tests Independent**: اختبارات لا تعتمد على بعضها
7. **Fast Tests**: اجعل الاختبارات سريعة
8. **Readable**: اكتب كود اختبار واضح ومقروء
