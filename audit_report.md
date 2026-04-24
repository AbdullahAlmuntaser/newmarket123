# تقرير مراجعة مسارات وواجهات نظام Supermarket ERP
**تاريخ التقرير:** الجمعة، 24 أبريل 2026

---

## 📋 1. مراجعة المسارات (Routes Audit)
تم فحص ملف `lib/main.dart` ومطابقته مع الملاحة الفعلية:

| المسار (Path) | الواجهة المرتبطة | الحالة | الملاحظات |
| :--- | :--- | :--- | :--- |
| `/` | `HomePage` | ✅ سليم | |
| `/login` | `LoginPage` | ✅ سليم | |
| `/pos` | `PosPage` | ✅ سليم | |
| `/sales/invoice` | `SalesInvoicePage` | ⚠️ تنبيه | يتم استدعاؤه بـ `Navigator.pushNamed` مما يسبب تعارضاً مع GoRouter. |
| `/accounting/manual-voucher` | `ManualVoucherPage` | ⚠️ ناقص | المسار معرف برمجياً لكنه غير موجود في القائمة الجانبية (Drawer). |
| `/sync` | -- | ❌ مفقود | موجود في القائمة الجانبية كخيار ولكن المسار غير معرف برمجياً. |
| `/customers/statement/:id` | `CustomerStatementPage` | ⚠️ غير مفعل | الخيار في القائمة الجانبية يوجه لصفحة القائمة العامة بدلاً من كشف الحساب. |

---

## 🖼️ 2. مراجعة الواجهات (UI Screens Audit)
تم رصد ملفات برمجية لواجهات مكتملة ولكنها "يتيمة" (غير مربوطة بمسار أو زر):

- **التصنيع:** `lib/presentation/features/manufacturing/bom_management_page.dart`
- **الموردين:** `lib/presentation/features/suppliers/add_supplier_payment_page.dart` (صفحة الدفع).
- **المشتريات:** `lib/presentation/features/purchases/purchase_orders_page.dart` (أوامر الشراء).
- **المخزون:** `lib/presentation/features/inventory/low_stock_alert_page.dart` (تنبيهات مخصصة).
- **التقارير:** `lib/presentation/features/reports/profitability_report_page.dart` (تقرير الأرباح الشهري العام).

---

## 🔗 3. الربط البرمجي (Functionality Linkage)
فحص الأزرار والعمليات الأساسية:

- **فاتورة المبيعات:** مرتبطة بشكل سليم بمحرك العمليات `TransactionEngine`.
- **فاتورة المشتريات:** مرتبطة بشكل سليم بـ `PurchaseService`.
- **الملاحة في الموردين:** يوجد خلل في `suppliers_page.dart` حيث يستخدم `Navigator.push` بدلاً من `context.push`.
- **الملاحة في سجل المبيعات:** يوجد خلل في `sales_history_page.dart` حيث يستخدم `Navigator.pushNamed`.

---

## 🚀 4. التوصيات النهائية (Roadmap for Fixes)

1. **توحيد نظام الملاحة:**
   - استبدال كل `Navigator.push` بـ `context.push()`.
   - استبدال كل `Navigator.pushNamed` بـ `context.push()`.

2. **تحديث ملف `main.dart`:**
   - إضافة مسار `/sync` لربطه بواجهة المزامنة.
   - إضافة مسارات للواجهات اليتيمة (BOM، أوامر الشراء).

3. **تحديث القائمة الجانبية (Main Drawer):**
   - إضافة خيار "سندات القبض والصرف" تحت قسم المحاسبة.
   - إضافة خيار "إدارة التصنيع" تحت قسم المنتجات أو قسم منفصل.

4. **إصلاح كشوفات الحساب:**
   - تعديل أزرار "كشوفات الحساب" في قائمة العملاء لتوجه إلى المسار الديناميكي `/customers/statement/ID`.

---
*تم إعداد هذا التقرير بواسطة مساعد Gemini CLI.*
