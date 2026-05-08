# 🚨 FULL ENTERPRISE ERP AUDIT + UI/UX + ARCHITECTURE + SECURITY + COMPLETION MISSION

🎯 ROLE:
أنت Enterprise ERP Architect + Senior Flutter Engineer + Systems Auditor + UX Functional Analyst + Database Architect + Financial Systems Expert.

أنت مسؤول عن تنفيذ:
- فحص عميق جداً للمشروع بالكامل
- تحليل معماري
- تحليل وظيفي
- تحليل تشغيلي
- تحليل الواجهات والشاشات
- تحليل الربط بين الواجهات والمنطق
- تحليل الأمان
- تحليل الأداء
- تحليل المحاسبة والمخزون
- اكتشاف الثغرات والفجوات
- إصلاح المشاكل
- استكمال الأنظمة الناقصة
- إعادة هيكلة الخدمات
- تحويل المشروع إلى Enterprise Production-Ready ERP

🚨 مهم جداً:
لا تتعامل مع المشروع كأنه مجرد Flutter App.
تعامل معه كنظام ERP حقيقي يخدم:
- محاسبة
- مخزون
- مبيعات
- مشتريات
- تصنيع
- ضرائب
- تقارير مالية

---

# 🎯 المطلوب الرئيسي

قم بفحص وتحليل كامل وعميق جداً لكل المشروع:

- lib/
- core/
- data/
- domain/
- presentation/
- ui/
- pages/
- screens/
- widgets/
- services/
- blocs/
- providers/
- DAOs
- Drift database
- transaction engines
- accounting engines
- inventory engines
- routing/navigation
- settings systems
- permissions systems

ثم قم بتنفيذ:
- التحليل
- اكتشاف المشاكل
- الإصلاحات
- إعادة الهيكلة
- تحسين الأداء
- سد الثغرات
- استكمال النواقص

بطريقة Enterprise Grade حقيقية.

---

# 🚨 فحص الواجهات والشاشات (مهم جداً)

قم بفحص شامل وعميق لكل:

- الصفحات
- الشاشات
- النوافذ
- الحوارات
- Bottom Sheets
- Forms
- Tables
- Reports
- Navigation
- Search
- Filters
- Inputs
- Buttons
- Menus
- Settings
- Dashboards

---

# 🎯 المطلوب في فحص الواجهات

تحقق من:

## ✅ هل الشاشة حقيقية أم وهمية
اكتشف:
- Placeholder pages
- TODO pages
- mock screens
- fake statistics
- dummy reports
- unconnected UI

---

## ✅ هل الواجهة مربوطة فعلياً بالمنطق
تحقق:
- هل الأزرار تعمل فعلياً
- هل الحفظ حقيقي
- هل الحذف يعمل
- هل التعديل يعمل
- هل البيانات تأتي من DB حقيقية
- هل العمليات تؤثر على النظام فعلياً

---


### المشتريات
- إنشاء فاتورة
- تعديل
- حذف
- تكلفة إضافية
- دفعات
- مرتجعات

---

### المخزون
- تحويلات
- جرد
## ✅ فحص التدفقات التشغيلية الكاملة

قم بمحاكاة كاملة داخل الواجهات لـ:

### المبيعات
- إنشاء فاتورة
- تعديل
- حذف
- مرتجع
- خصومات
- دفع جزئي
- دفع آجل
- تعليق الفاتورة
- استئنافها
- طباعة

---
- تسويات
- هالك
- تتبع الدفعات
- FEFO/FIFO

---

### المحاسبة
- قيود
- ترحيل
- إلغاء ترحيل
- ميزانية
- قائمة دخل
- دفتر أستاذ
- ميزان مراجعة

---

# 🚨 فحص الترابط بين الواجهات والـ Backend

تحقق من:
- أي شاشة غير مربوطة
- أي زر لا ينفذ عملية حقيقية
- أي إعداد لا يؤثر فعلياً
- أي صفحة تعرض بيانات وهمية
- أي تقرير غير حقيقي
- أي عملية لا تُحدث DB
- أي عملية لا تنشئ قيود محاسبية صحيحة

---

# 🚨 فحص حالات الواجهة الحرجة

تحقق من:

## Error States
- فشل الحفظ
- انقطاع البيانات
- فشل الترحيل
- أخطاء SQL

---

## Loading States
- هل يوجد تحميل حقيقي
- هل الواجهة تتجمد
- هل يوجد infinite loading

---

## Empty States
- هل الواجهة تتعامل مع عدم وجود بيانات

---

## Offline Handling
- ماذا يحدث عند ضعف الاتصال
- ماذا يحدث عند بطء العمليات

---

## Form Validation
تحقق:
- الحقول المطلوبة
- الأرقام السالبة
- القيم غير المنطقية
- التواريخ
- العملات
- الضرائب

---

# 🚨 فحص UX الحقيقي

حلل:
- سهولة الاستخدام
- سرعة العمليات
- كثافة النقرات
- وضوح التنقل
- أخطاء المستخدم المحتملة
- تدفق العمل المحاسبي
- تجربة الكاشير
- تجربة المحاسب
- تجربة إدارة المخزون

---

# 🚨 PERFORMANCE ANALYSIS

حلل:
- rebuild storms
- unnecessary rebuilds
- large widget rebuilds
- memory leaks
- slow lists
- large tables
- nested streams
- expensive queries

خصوصاً:
- POS
- Reports
- Accounting Screens
- Inventory Tables

---

# 🚨 DATABASE + BACKEND ANALYSIS

افحص:
- indexes
- slow queries
- aggregation issues
- missing transactions
- concurrency problems
- race conditions
- rollback safety

---

# 🚨 SECURITY ANALYSIS

تحقق من:
- Permission bypass
- role enforcement
- unauthorized operations
- hidden admin actions
- unsafe deletes
- unsafe edits

خصوصاً:
permission_service.dart

إذا كانت:
check() => true

قم بتحويلها فوراً إلى:
RBAC حقيقي يعتمد على:
- users
- roles
- permissions
- database rules

---

# 🚨 ACCOUNTING INTEGRITY

تحقق:
- توازن القيود
- سلامة القيود المرحّلة
- صحة الأرصدة
- صحة الضرائب
- صحة المخزون
- التوافق بين المحاسبة والمخزون

---

# 🚨 منع الكوارث التشغيلية

تأكد:
- لا يوجد stock corruption
- لا يوجد balance corruption
- لا يوجد partial transactions
- لا يوجد orphan records
- لا يوجد duplicate postings

---

# 🚨 ARCHITECTURE REFACTOR

قم بتحليل:
- God Classes
- Fat Services
- duplicated logic
- business logic leakage
- DAO misuse
- tight coupling

ثم قم بإعادة الهيكلة.

---

# 🚨 ERP COMPLETION

استكمل الأنظمة الناقصة:

## Budgets
- budgets
- variance analysis
- budget reports

---

## Fiscal Closing
- closing entries
- opening balances
- fiscal lock

---

## Multi Currency
- exchange rates
- conversion
- gains/losses

---

## Multi Branch
- branch isolation
- branch inventory
- branch accounting

---

# 🚨 TESTING

أنشئ:
- unit tests
- integration tests
- UI workflow tests
- accounting integrity tests
- inventory integrity tests
- transaction rollback tests

---

# 🚨 OUTPUT FORMAT (إجباري)

لكل مشكلة أو فجوة:

## 1️⃣ نوع المشكلة
- UI
- Backend
- Architecture
- Accounting
- Inventory
- Security
- Performance
- UX

---

## 2️⃣ الوصف التقني

---

## 3️⃣ الخطورة
- Critical
- High
- Medium
- Low

---

## 4️⃣ التأثير الفعلي

---

## 5️⃣ السبب الجذري

---

## 6️⃣ الملفات المتأثرة

---

## 7️⃣ الإصلاح المطلوب

---

## 8️⃣ الكود المعدل

---

## 9️⃣ لماذا هذا الحل صحيح

---

# 🚨 قواعد صارمة

- لا تستخدم TODO
- لا تستخدم Mock Logic
- لا تستخدم Placeholder
- لا تشرح فقط
- نفذ التعديلات الحقيقية
- لا تكسر النظام الحالي
- لا تحذف منطق بدون فهم تأثيره
- حافظ على سلامة البيانات المحاسبية والمخزنية
- تعامل مع المشروع كنظام ERP Enterprise حقيقي

ابدأ الآن بفحص المشروع بالكامل بعمق شديد ثم نفذ الإصلاحات مرحلة مرحلة مع تقارير تفصيلية بعد كل مرحلة.
ملاحظه. مهمه يمكنك تقسيم العمل الى راحل لكي تسهل عمليه التنفيذ حتا اذا توقفنا. نعود ونحن نعرففياي مرحله
