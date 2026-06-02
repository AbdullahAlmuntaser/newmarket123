# وثيقة الإصلاح الشامل لنظام SystemMarket

## 🎯 الهدف

إصلاح فوري ومتكامل لمشاكل الدقة المالية، تقييم المخزون، منطق الترحيل، التوطين، والبنية الأساسية، مع ضمان سلامة البيانات واستقرار النظام عبر اختبارات آلية شاملة.

---

## 1️⃣ تصحيح خوارزمية تقييم المخزون (LIFO)

### الملف المستهدف
`lib/core/services/inventory_costing_service.dart`

### المشاكل الموجودة
1. **LIFO في تقييم المخزون لا يُطبق فعلياً** — الدالتان `_calculateFifoValuation` و `_calculateLifoValuation` تقومان بنفس العملية الحسابية (جمع الكميات وتقسيمها) بدلاً من تطبيق LIFO فعلياً الذي يحسب قيمة المخزون المتبقي بناءً على أقدم الدُفعات (FIFO يعكس LIFO هنا).
2. **جميع دوال التقييم تستخدم `double`** بينما قاعدة البيانات تخزن الكميات والتكاليف بصيغة `Decimal`.
3. **دالة `calculateCogsForSale`** تقوم بتحويل `Decimal → double → Decimal → double` مما يفقد الدقة.
4. **`InventoryValuation` و `BatchWithCost`** يستخدمان `double` لجميع الحقول المالية.

### المطلوب
- إعادة كتابة `_calculateLifoValuation` بحيث تحسب قيمة المخزون كالتالي:
  - تُرَتَّب الدُفعات تصاعدياً حسب `createdAt` (الأقدم أولاً).
  - قيمة المخزون = مجموع (كمية الدُفعة × تكلفتها) لأحدث الدُفعات التي تغطي الكمية الإجمالية.
  - متوسط التكلفة = قيمة المخزون / الكمية الإجمالية.
- إعادة كتابة `_calculateFifoValuation` بالمقلوب:
  - تُرَتَّب الدُفعات تنازلياً حسب `createdAt` (الأحدث أولاً).
  - قيمة المخزون = مجموع تكاليف أقدم الدُفعات التي تغطي الكمية.
- تحويل جميع حقول `InventoryValuation` و `BatchWithCost` من `double` إلى `Decimal`.
- إزالة كل تحويلات `.toDouble()` من دوال التقييم وحساب التكاليف.
- جعل `calculateCogsForSale` تتعامل مع `Decimal` فقط وتُرجِع `Decimal`.

### مثال مرجعي (LIFO)
```
دُفعة 1: 10 وحدات × 10 ريال = 100  (منذ 30 يوماً)
دُفعة 2: 10 وحدات × 12 ريال = 120  (منذ 20 يوماً)
دُفعة 3: 10 وحدات × 15 ريال = 150  (منذ 10 أيام)

تقييم LIFO لمخزون 15 وحدة:
  أحدث 15 وحدة = 10 (د3) × 15 + 5 (د2) × 12 = 150 + 60 = 210 ريال
  متوسط التكلفة = 210 / 15 = 14.00 ريال
```

---

## 2️⃣ استبدال double بـ Decimal في جميع العمليات المالية

### النطاق
- **Services**: `inventory_costing_service.dart`, `transaction_engine.dart`, `accounting_service.dart`, `sales_service.dart`, `purchase_service.dart`, `return_service.dart`, `cash_management_service.dart`, `financial_closing_service.dart`
- **Data Access**: `app_database.dart` (التأكد من أن `DecimalConverter` يُستخدم لكل الحقول المالية)
- **Models**: `gl_entry_detail.dart` (تغيير `debit` و `credit` من `double` إلى `Decimal`)
- **Data Classes**: `SaleWithBalance`, `InventoryValuation`, `BatchWithCost`
- **All DAOs**: التأكد من أن جميع الاستعلامات المالية تستخدم `Decimal`

### قواعد التحويل الإلزامية
| النمط القديم | النمط الجديد |
|---|---|
| `double` في الحقول المالية | `Decimal` |
| `.toDouble()` | إزالة — التعامل المباشر مع `Decimal` |
| `double.parse(...)` | `Decimal.parse(...)` |
| `double total = a + b` | `Decimal total = a + b` (مع `Decimal`) |
| `a * b.toDouble()` | `a * b` (حيث `a`, `b` هما `Decimal`) |
| مقارنات `>` مع `double` | مقارنات `>` مع `Decimal` |

### استثناءات مسموح بها
- الكميات الفيزيائية (عدد القطع، الكيلوغرامات) المستخدمة في واجهة المستخدم فقط — وليس في حسابات الترحيل.
- الإحصائيات والتقارير البيانية (الرسوم البيانية) يمكنها استخدام `double` بعد التحويل النهائي من `Decimal`.

### حالات الاختبار المرجعية
```dart
// يجب أن تمر جميعها
test('LIFO COGS using Decimal precision', () {
  final cogs = calculator.calculateCogsForSale(productId, Decimal.fromInt(15));
  expect(cogs, equals(Decimal.fromInt(210)));  // 10×15 + 5×12
});

test('no double conversion in financial path', () {
  // التأكد من أن التدفق الكامل لا يستدعي .toDouble()
});
```

---

## 3️⃣ توحيد منطق الترحيل (TransactionEngine)

### المشكلة
يوجد مساران للترحيل:
1. **`TransactionEngine.postSale()`** — المسار الحديث والمتكامل (يستخدم `InventoryCostingService`، يسجل حركات المخزون، يحدث الأرصدة، يستدعي المحاسبة، ويسجل audit log).
2. **`SalesService.processInvoice()`** — مسار قديم (يستخدم `PostingEngine.post()` مع profile-based posting فقط، ولا يتكامل مع `InventoryCostingService` أو `TransactionEngine`).

### المطلوب
1. **إيقاف `SalesService.processInvoice()`** — إما بإزالته أو بإعادة توجيهه إلى `TransactionEngine.postSale()`.
2. **جعل `TransactionEngine` المصدر الوحيد** لجميع الترحيلات:
   - `postSale()` — ترحيل المبيعات
   - `postPurchase()` — ترحيل المشتريات
   - `postSaleReturn()` — ترحيل مرتجعات المبيعات
   - `postPurchaseReturn()` — ترحيل مرتجعات المشتريات
   - `postCustomerPayment()` — ترحيل مدفوعات العملاء
   - `postSupplierPayment()` — ترحيل مدفوعات الموردين
3. **التأكد من عدم وجود أي كود خارج `TransactionEngine`** يقوم بترحيل القيود المحاسبية أو تحديث أرصدة المخزون مباشرة.
4. **فحص شامل** لجميع الملفات التي تستدعي `PostingEngine.post()` أو تعدل `product_batches` مباشرة.

### قائمة الفحص
- [ ] `lib/core/services/sales_service.dart` — إعادة توجيه إلى `TransactionEngine` أو إزالة
- [ ] `lib/core/services/purchase_service.dart` — التأكد من استخدام `TransactionEngine.postPurchase()`
- [ ] `lib/core/services/return_service.dart` — التأكد من استخدام `TransactionEngine.postSaleReturn/PostPurchaseReturn()`
- [ ] أي كود في الـ UI Blocs/Pages يستدعي `PostingEngine.post()` مباشرة

---

## 4️⃣ تنفيذ ميجريشنات Backfill مع دعم Rollback

### الملفات المستهدفة
- `tool/run_hr_backfill.dart`
- `lib/data/datasources/local/app_database.dart` — دالتي `_backfillHrUuidIdsSafe` و `_backfillHrUuidIds`

### المطلوب

#### 4.1 إصلاح `_backfillHrUuidIdsSafe`
حالياً هي no-op. يجب تحويلها إلى دالة فعّالة:
- فحص ما إذا كانت الجداول تحتوي على UUIDs صالحة أم أرقام legacy.
- تحويل الأرقام إلى UUIDs مع تحديث المراجع.
- كتابة SQL audit trail في التعليقات.

#### 4.2 إضافة Rollback
لكل backfill، يجب كتابة دالة rollback مقابلة تسجل:
```sql
-- rollback script generated at <timestamp>
-- backfill: <ticket-id>
-- affected rows: employees=X, payroll_details=Y
-- rollback: UPDATE employees SET id = <old_id> WHERE id = <new_id>;
```

```dart
class BackfillManager {
  Future<void> runBackfill({required String name, required Future<void> Function() forward, required Future<void> Function() rollback, bool dryRun = false}) async {
    if (dryRun) {
      await logAudit('DRY_RUN: $name — no changes applied');
      return;
    }
    await backupRelevantTables(name);
    try {
      await forward();
      await logAudit('BACKFILL_COMPLETED: $name');
    } catch (e) {
      await logAudit('BACKFILL_FAILED: $name — $e');
      try {
        await rollback();
        await logAudit('ROLLBACK_COMPLETED: $name');
      } catch (r) {
        await logAudit('ROLLBACK_FAILED: $name — $r');
      }
      rethrow;
    }
  }
}
```

#### 4.3 سكربتات مستقلة
- `tool/run_hr_backfill.dart` — يجب أن يدعم `--rollback` كمعامل
- إضافة `tool/run_financial_recalc.dart` — لإعادة حساب البيانات المالية التاريخية
- إضافة `tool/run_inventory_revaluation.dart` — لإعادة تقييم المخزون حسب LIFO

#### 4.4 النسخ الاحتياطي
- قبل أي backfill، إنشاء نسخة احتياطية من الجداول المتأثرة:
  ```sql
  CREATE TABLE backup_<table>_<timestamp> AS SELECT * FROM <table>;
  ```

---

## 5️⃣ توطين النصوص وإعادة بناء Layout شاشة POS

### 5.1 إزالة النصوص الصلبة

#### الملفات المستهدفة
- `lib/l10n/app_ar.arb` — الإضافة إليها (حالياً ~410 مفتاح)
- `lib/l10n/app_en.arb` — الإضافة إليها (حالياً ~407 مفتاح)
- جميع ملفات `.dart` في `lib/presentation/` و `lib/ui/`

#### الإجراء
1. فحص جميع ملفات الـ UI بحثاً عن نصوص عربية أو إنجليزية مكتوبة مباشرة (hardcoded strings).
2. نقل كل نص مصادف إلى ملفي `app_ar.arb` و `app_en.arb` تحت مفتاح مناسب.
3. استبدال النص في الكود باستخدام `AppLocalizations.of(context)!.<key>`.
4. أمثلة على المفاتيح المفقودة حالياً (غير موجودة في ARB):
   - "جاري تهيئة النظام..." / "Initializing system..."
   - "لا توجد فترة محاسبية مفتوحة حالياً" / "No open accounting period"
   - "تم معالجة فاتورة المبيعات رقم" / "Sales invoice processed"
   - "المخزون غير كافٍ للمنتج" / "Insufficient stock for product"
   - "خطأ في العملية" / "Operation error"
   - "لا يمكن إجراء عملية بيع نقدي بدون فتح وردية عمل" / "Cannot process cash sale without open shift"
   - "هذه الفاتورة تم ترحيلها بالفعل" / "This invoice has already been posted"

### 5.2 إعادة بناء Layout شاشة POS

#### المبادئ
- **Responsive Design**: استخدام `LayoutBuilder` و `MediaQuery` لدعم:
  - الأجهزة اللوحية (Tablets) — العرض الأفقي
  - الهواتف (Phones) — العرض الرأسي
  - الشاشات الصغيرة جداً (< 360px) — تكييف تام
- **تقسيم الشاشة**:
  - `ProductGrid` — شبكة منتجات قابلة للتمرير
  - `CartPanel` — لوحة السلة الجانبية (عرض جانبي في tablet / سفلي في phone)
  - `SearchBar` — شريط بحث مع فلترة
  - `PaymentModal` — مودال الدفع (قابل لإعادة الاستخدام)
- **Widget Tree مقترح**:
  ```
  POSPage
    ├── LayoutBuilder
    │   ├── Tablet: Row(ProductGrid, CartPanel)
    │   └── Phone: Column(ProductGrid, CartPanel)
    ├── SearchBar
    ├── FloatingActionButton (إتمام البيع)
    └── PaymentModal (يظهر عند الضغط)
  ```

---

## 6️⃣ اختبارات آلية شاملة

### 6.1 اختبارات الوحدة (Unit Tests)

#### الملف: `test/services/inventory_costing_test.dart`
- إعادة هيكلة لاختبار `InventoryCostingService` الفعلي (وليس `InventoryCostingCalculator` المنفصل).
- استخدام `MockAppDatabase` و `MockStockMovementDao` لعزل الخدمة.
- تغطية السيناريوهات:

| السيناريو | LIFO | FIFO | AVCO |
|---|---|---|---|
| 3 دفعات — COGS لـ 15 وحدة | 210 | 160 | 250 |
| دفعة واحدة فقط | تطابق FIFO | تطابق LIFO | نفس التكلفة |
| دفعات فارغة | 0 | 0 | 0 |
| كميات تتجاوز المتاح | المتاح فقط | المتاح فقط | المتاح فقط |
| تقييم المخزون بالكامل | 270 | 270 | 270 avg=13.33 |

#### الملف: `test/services/accounting_service_test.dart`
- اختبار دالة `postSale()` مع `Decimal`:
  ```dart
  test('postSale creates balanced GL entries using Decimal', () { ... });
  ```
- اختبار دوال التقارير المالية (`getIncomeStatement`, `getBalanceSheet`) بدقة `Decimal`.

### 6.2 اختبارات التكامل (Integration Tests)

#### الملف: `test/integration/posting_flow_test.dart` (جديد)
- تغطية المسار الكامل: `TransactionEngine.postSale()` → `InventoryCostingService` → `AccountingService`
- التأكيد على:
  - توازن القيود (debit == credit باستخدام `Decimal`)
  - تحديث أرصدة الدُفعات بشكل صحيح
  - تسجيل audit log
  - عدم وجود أي استدعاء لـ `PostingEngine.post()` من خارج `TransactionEngine`

#### الملف: `test/integration/lifo_costing_flow_test.dart` (جديد)
- محاكاة دورة كاملة: شراء 3 دفعات ← بيع 15 وحدة ← تقييم LIFO
- مقارنة النتائج مع الحالات المرجعية المعروفة

### 6.3 اختبارات البيانات المرجعية (Reference Data Tests)

#### ملف: `test/reference/lifo_reference_test.dart` (جديد)
```dart
// حالات مرجعية موثقة من ISO 27001 / GAAP
const referenceCases = {
  'LIFO_case_1': {
    'batches': [/* 3 batches */],
    'saleQty': 15,
    'expectedCogs': Decimal.fromInt(210),
    'expectedValuation': Decimal.fromInt(270),
    'tolerance': Decimal.parse('0.001'),
  },
  // ...
};
```

### 6.4 معايير القبول للاختبارات
- ✅ جميع اختبارات الوحدة تمر في أقل من 30 ثانية
- ✅ جميع اختبارات التكامل تمر في أقل من 120 ثانية
- ✅ نسبة تغطية الكود > 85% للملفات المستهدفة
- ✅ لا يوجد `.toDouble()` في أي مسار مالي بعد التعديل (يُفحص بـ static analysis)
- ✅ كل تذكرة إصلاح يرافقها اختبار يثبت صحتها

---

## 7️⃣ هيكل الفروع (Branching Strategy)

```
main
├── hotfix/lifo-valuation           ← الإصلاح 1
├── hotfix/decimal-migration         ← الإصلاح 2
├── hotfix/unified-posting           ← الإصلاح 3
├── hotfix/backfill-migrations       ← الإصلاح 4
├── hotfix/localization-arb          ← الإصلاح 5
├── hotfix/pos-layout-responsive     ← الإصلاح 5
└── hotfix/test-coverage             ← الإصلاح 6
```

كل فرع يتم اختباره بشكل منفصل قبل الدمج إلى `main`.

---

## 8️⃣ خطة النشر والإسترجاع

### قبل النشر إلى الإنتاج
```
1. أخذ نسخة احتياطية كاملة:  pg_dump / sqlite3 backup
2. تشغيل الاختبارات المرجعية: flutter test test/reference/
3. تشغيل التكامل:             flutter test test/integration/
4. تشغيل الفحص الثابت:        flutter analyze --fatal-infos
5. النشر إلى بيئة اختبار (Staging) مع نسخة مصغرة من بيانات الإنتاج
6. تشغيل Backfill في Staging مع --dry-run أولاً
7. التحقق اليدوي من النتائج
8. النشر إلى الإنتاج
```

### خطة الاسترجاع
```
1. إيقاف التطبيق
2. استعادة النسخة الاحتياطية من قاعدة البيانات
3. الرجوع إلى الإصدار السابق من الكود (git revert)
4. التحقق من الاستقرار
5. إعادة تشغيل التطبيق
```

---

## 9️⃣ توثيق التغييرات

كل تغيير يجب أن يُوثَّق بالتنسيق التالي:

```markdown
### [TICKET-ID] وصف التغيير
- **الملفات المتأثرة**:
  - `lib/core/services/inventory_costing_service.dart:165-186`
- **نوع التغيير**: تصحيح / تحسين / إعادة هيكلة
- **نتائج الاختبارات**:
  - ✅ test/reference/lifo_reference_test.dart — LIFO_case_1: COGS=210 (Decimal)
  - ✅ test/services/inventory_costing_test.dart — LIFO valuation: 270 (Decimal)
- **التأثير المالي المتوقع**:
  - تحسين دقة تكلفة المبيعات بنسبة ±0.001%
  - إزالة فروقات التقريب الناتجة عن double
```

---

## 📋 جدول المهام النهائي

| # | المهمة | الأولوية | الفرع | ملفات التأثير |
|---|---|---|---|---|
| 1 | تصحيح LIFO في InventoryCostingService | عالية | `hotfix/lifo-valuation` | `inventory_costing_service.dart` |
| 2 | تحويل double → Decimal في جميع Services | عالية | `hotfix/decimal-migration` | `gl_entry_detail.dart`, `transaction_engine.dart`, `accounting_service.dart`, وغيرها |
| 3 | توحيد الترحيل في TransactionEngine | عالية | `hotfix/unified-posting` | `sales_service.dart`, `purchase_service.dart`, `return_service.dart` |
| 4 | تنفيذ Backfill مع Rollback | متوسطة | `hotfix/backfill-migrations` | `app_database.dart`, `run_hr_backfill.dart`, `run_financial_recalc.dart` |
| 5 | توطين النصوص → ARB | متوسطة | `hotfix/localization-arb` | `app_ar.arb`, `app_en.arb`, جميع ملفات UI |
| 6 | إعادة بناء Layout POS | متوسطة | `hotfix/pos-layout-responsive` | ملفات POS UI |
| 7 | اختبارات وحدات وتكامل | عالية | `hotfix/test-coverage` | جميع ملفات `test/` الجديدة |

---

> **تاريخ الإعداد**: 2026-06-01  
> **الحالة**: 🟡 قيد التنفيذ  
> **آخر تحديث**: الإصدار 1.0
