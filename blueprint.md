

🌟 برومبت Gemini Ultimate: ERP متكامل مع إدارة العملاء، المبيعات، المشتريات، والمنتجات

Instruction:
أنت مساعد ذكي لتطوير أنظمة ERP باستخدام Flutter وSQLite (Drift). مهمتك: تحويل النظام المحاسبي الحالي إلى ERP كامل (Enterprise Level) مع التركيز على إدارة العملاء، المبيعات، المشتريات، المنتجات، المخزون، والصلاحيات. اتبع هذه الخطة خطوة خطوة، مع ترتيب الأولويات وتوضيح الجداول والحقول المطلوبة لكل مرحلة. لا تكتب أي كود، فقط خطط ومخططات دقيقة جاهزة للتنفيذ.


---

المرحلة 1: إدارة العملاء Customers

المهام:

1. إنشاء جدول Customers يحتوي على:

customerId, name, contactInfo, creditLimit, accountId



2. ربط كل عميل بحساباته المحاسبية


3. إنشاء كشف حساب مستقل لكل عميل


4. تسجيل جميع المعاملات: المبيعات، الدفعات، المرتجعات


5. دعم Credit / Cash Transactions



Outcome:
نظام قادر على إدارة العملاء بشكل احترافي، مع تتبع كامل لكل العمليات المالية المتعلقة بهم.


---

المرحلة 2: إدارة الموردين Suppliers

المهام:

1. إنشاء جدول Suppliers يحتوي على:

supplierId, name, contactInfo, accountId



2. ربط الموردين بالحسابات المحاسبية


3. إنشاء كشف حساب مستقل لكل مورد


4. تسجيل جميع المعاملات: المشتريات، المدفوعات، المرتجعات



Outcome:
ERP قادر على إدارة الموردين بشكل كامل مع المحاسبة المرتبطة.


---

المرحلة 3: إدارة المنتجات Items / Products

المهام:

1. إنشاء جدول Products يحتوي على:

productId, name, SKU, categoryId, unitPrice, taxRate, stockQty



2. دعم عدة مستودعات لكل منتج


3. دعم Stock Movements Ledger لكل عملية شراء، بيع، تحويل، أو مرتجع


4. دعم Inventory Valuation History



Outcome:
ERP يدير المنتجات بكفاءة مع ربطها بالمخزون والمحاسبة.


---

المرحلة 4: إدارة المبيعات Sales Management

المهام:

1. إنشاء جداول:

SalesOrders

SalesOrderItems

SalesInvoices

SalesInvoiceItems



2. حالات المبيعات والفواتير: Draft, Confirmed, Posted, Paid, Cancelled


3. دعم Customer Ledger لكل عملية


4. ربط كل عملية مبيعات بالقيود المحاسبية


5. دعم Discounts, Offers, Price Lists لكل عميل أو منتج


6. ربط المبيعات بالمخزون: خصم الكمية تلقائيًا حسب FIFO



Outcome:
نظام مبيعات كامل مترابط مع العملاء، المحاسبة، والمخزون.


---

المرحلة 5: إدارة المشتريات Purchase Management

المهام:

1. إنشاء جداول:

PurchaseOrders

PurchaseOrderItems

PurchaseInvoices

PurchaseInvoiceItems



2. حالات المشتريات والفواتير: Draft, Confirmed, Posted, Paid, Cancelled


3. ربط كل عملية مشتريات بالقيود المحاسبية


4. ربط كل عملية مشتريات بالمخزون: إضافة الكميات تلقائيًا حسب FIFO


5. دعم Supplier Ledger لكل مورد



Outcome:
ERP قادر على إدارة المشتريات بالكامل، مع المحاسبة والمخزون.


---

المرحلة 6: المخزون Inventory Management

المهام:

1. إنشاء جدول StockMovements لتسجيل كل حركة: بيع، شراء، مرتجع، تحويل بين مستودعات


2. سجل Inventory Valuation History


3. دعم Multi-Warehouse


4. ربط المخزون بالمحاسبة تلقائيًا



Outcome:
إدارة مخزون متقدمة، دقيقة، ومرتبطة بالكامل بالعمليات المالية.


---

المرحلة 7: المستودعات Warehouses

المهام:

1. دعم التحويل بين المستودعات


2. صلاحيات لكل مستودع حسب الدور الوظيفي



Outcome:
ERP قادر على إدارة مستودعات متعددة بشكل احترافي وآمن.


---

المرحلة 8: الصلاحيات Permissions

المهام:

1. إنشاء جداول: Users, Roles, Permissions


2. أمثلة:

محاسب → لا يحذف قيود

كاشير → لا يرى التقارير

مدير → كل الصلاحيات




Outcome:
نظام أمان متكامل يدير وصول المستخدمين بشكل دقيق.


---

المرحلة 9: تسجيل النشاطات Audit Log

المهام:

1. حفظ Before / After values لكل عملية


2. ربط السجلات بالمعاملات Transaction ID



Outcome:
تدقيق كامل لكل العمليات مع سجل تغييرات شامل.


---

المرحلة 10: التسويات المالية Reconciliation

المهام:

1. Bank Reconciliation


2. Cash Reconciliation



Outcome:
ERP قادر على إدارة التسويات النقدية والمصرفية بشكل آمن.


---

المرحلة 11: تحسينات متقدمة Advanced Features

1. فصل Domains: Accounting Service, Inventory Service, Sales Service


2. Event Driven Architecture: SaleCreated Event → Accounting Listener


3. دعم Multi-Currency: currency + exchangeRate


4. دعم Multi-Company: CompanyId في كل جدول


5. نظام تسعير متقدم: Price Lists, Discounts, Offers



Outcome:
ERP مرن، قابل للتوسع، واحترافي على مستوى مؤسسات كبيرة.


---

ملاحظات ختامية للـ Gemini Assistant

ابدأ بالأولويات:
1 → نظام القيود والموافقة
2 → الفترات المحاسبية
3 → إدارة العملاء والموردين
4 → إدارة المبيعات والمشتريات
5 → إدارة المنتجات والمخزون
6 → المستودعات والصلاحيات

كل جدول يجب أن يكون مرتبطًا بشكل صحيح بالمعاملات المالية والتقارير

ركز على دقة البيانات وقابلية التوسع للشركات متعددة الفروع والعملات


💡 Goal: بعد تنفيذ هذا البرومبت، يصبح النظام ERP كامل، Enterprise Ready، مع إدارة متقدمة للعملاء، الموردين، المبيعات، المشتريات، المنتجات، المخزون، والمحاسبة، وقابل للتوسع بشكل كامل.


---

إ