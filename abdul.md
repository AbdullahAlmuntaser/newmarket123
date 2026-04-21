هذا برومبت مرجع لك لكي تقوم بتنفيذ التحسينات المطلوبه. اي مرحله تنتهي منها تقوم بتاشيرها


---

🚀 البرومبت الموحد (ERP Enhancement Master Prompt)

أنت مهندس برمجيات خبير في تطوير أنظمة ERP باستخدام:

Flutter (Frontend)

Drift (SQLite)

Clean Architecture

Bloc/Cubit

Services Layer + DAO Layer


ومتخصص في تحسين الأنظمة القائمة بدون إعادة كتابة أو كسر أي وظائف.


---

🧩 النظام الحالي

لدي نظام ERP Offline يعمل ويحتوي على:

✔️ الوحدات الحالية

محاسبة مزدوجة (Double Entry Accounting)

مبيعات (POS)

مشتريات (Purchases + Returns)

مخزون (Batches + FEFO)

منتجات (Products Management)

transaction_engine

accounting_service

inventory_service



---

⚠️ قواعد صارمة (مهم جداً)

1. ❌ ممنوع إعادة بناء النظام من الصفر


2. ❌ ممنوع كسر أي Feature موجود


3. ❌ ممنوع وضع business logic داخل UI


4. ✔️ كل العمليات عبر Services فقط


5. ✔️ كل حركة مالية = قيد محاسبي تلقائي


6. ✔️ كل حركة مخزون = تمر عبر transaction_engine


7. ✔️ الحفاظ على نفس Architecture الحالي


8. ✔️ عدم تكرار الكود


9. ✔️ أي تحسين يجب أن يقلل الأخطاء ويزيد السرعة




---

🎯 الهدف العام

تحويل النظام إلى ERP احترافي مثل Odoo يشمل:

واجهات ذكية وسريعة

Workflow كامل للعمليات

تقارير مالية وتشغيلية

CRM متقدم

مخزون ذكي

صلاحيات وأمان

أداء عالي



---

🧱 المرحلة 1: تحسين واجهات المشتريات (Purchases UI)

🟢 1. اختيار المورد (Smart Supplier Selection)

عند اختيار المورد اعرض:

آخر سعر شراء لكل منتج

آخر تاريخ شراء

أفضل سعر سابق

رصيد المورد الحالي


📌 البيانات من:

purchases

purchase_items



---

🟢 2. بيانات المنتج أثناء الإدخال

عند إضافة منتج:

الكمية الحالية في المخزون

متوسط التكلفة

آخر سعر شراء

وحدة القياس والتحويلات



---

🟢 3. تنبيهات ذكية (Real-time)

السعر أعلى من المتوسط → تحذير

كمية كبيرة → تنبيه

مخزون مرتفع → اقتراح تقليل



---

🟢 4. تحسين سطر المنتج (Purchase Item Row)

كل سطر يحتوي:

quantity

unit

price

discount per item

tax

total


مع Live Calculation


---

🟢 5. خصومات ومصاريف الفاتورة

Discount invoice level

Costs:

شحن

نقل

جمارك



📌 توزيع التكاليف على المنتجات (Cost Allocation)


---

🟢 6. تحويل Purchase Order

زر: "تحويل إلى فاتورة"

تعبئة تلقائية كاملة



---

🟢 7. UX Improvements

Auto Focus

Barcode input

Draft saving

تقليل النقرات



---

🟦 المرحلة 2: تحسين واجهات المبيعات (Sales UI)

🟡 1. Sales Invoice Page جديدة

sales_invoice_page.dart

اختيار عميل

إضافة منتجات

طرق دفع

ملاحظات



---

🟡 2. بيانات العميل الذكية

الرصيد

الحد الائتماني

عدد الفواتير

آخر شراء



---

🟡 3. التسعير الذكي

retail price

wholesale price

customer-specific price



---

🟡 4. تنبيهات المبيعات

عدم توفر الكمية → منع

السعر أقل من التكلفة → تحذير

تجاوز credit limit → منع أو تنبيه



---

🟡 5. Sales Item Row

quantity

price

discount

tax

total


Live Update


---

🟡 6. الدفع

Cash

Credit

Partial Payment

Split Payments



---

🟡 7. المرتجعات داخل الفاتورة

زر: Return

اختيار مباشر من الفاتورة



---

⚡ المرحلة 3: تحسين POS

Barcode scanning

Speed optimization

Hotkeys

Stock visibility

Fast product search



---

🎨 تحسينات UX عامة

Search سريع (اسم / SKU / باركود)

Lazy Loading

Loading states

تقليل Popups

UI نظيف وسريع



---

🧠 المرحلة 4: نظام التقارير (Reports System)

📊 التقارير المالية

Income Statement

Balance Sheet

Cash Flow


📊 تقارير المبيعات

حسب المنتج

حسب العميل

حسب التاريخ


📊 تقارير المشتريات

حسب المورد


📊 المخزون

Inventory Valuation

Stock Ledger

Inventory Aging


📊 Dashboard

مبيعات يومية

أرباح

أفضل المنتجات


📌 إنشاء:

reports_service.dart

SQL Aggregations

Filters (date / product / warehouse)



---

🔄 المرحلة 5: Workflow System

🧾 المشتريات

Purchase Request

Purchase Order

Invoice


Flow: Request → Approval → Order → Receipt → Invoice


---

🧾 المبيعات

Quotation

Sales Order

Invoice


Flow: Quote → Approval → Order → Invoice


---

🧾 الموافقات

approval_rules

approval_logs


مثال:

> أي عملية فوق مبلغ معين تحتاج موافقة




---

📦 المرحلة 6: المخزون المتقدم

Reorder System

Auto Purchase Suggestions

Warehouses Management

Transfers

Fast / Slow Products



---

👥 المرحلة 7: CRM

Customer Segmentation

Loyalty Points

Credit Management

Aging Reports



---

🏷️ المرحلة 8: الموردين

Supplier Product Mapping

Price History

Best Supplier per Product



---

💰 المرحلة 9: المحاسبة المتقدمة

Cost Centers

Budgeting (Plan vs Actual)

Multi-Currency



---

🔐 المرحلة 10: الصلاحيات

Roles

Permissions:

Screen level

Action level (add/edit/delete/approve)




---

🔌 المرحلة 11: التكامل

REST API

Export Excel

Export PDF



---

⚡ المرحلة 12: الأداء

Pagination

Lazy Loading

DB Indexing

Cache Layer



---

🧪 طريقة التنفيذ الإلزامية

لكل مرحلة:

1. تحليل الكود الحالي


2. تحديد نقاط الربط


3. إنشاء:

Tables (Drift)

DAO

Services



4. ربط مع:

accounting_service

transaction_engine

inventory_service



5. بناء UI


6. اختبار كامل بدون كسر النظام




---

🎯 الهدف النهائي

تحويل النظام إلى ERP احترافي كامل يشمل:

Finance

Inventory

Sales

Purchases

CRM

Workflow

Reports

Permissions

Performance optimized



---

🚀 بداية التنفيذ

ابدأ مباشرة بـ:

👉 المرحلة 1: تحسين واجهات المشتريات + Sales UI

بدون الانتقال لأي مرحلة أخرى حتى يتم إكمالها بالكامل.


---
