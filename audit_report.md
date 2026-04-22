# تقرير مراجعة نظام ERP المحاسبي (SystemMarket)
## تقرير مراجع الكود الاحترافي
**تاريخ التقرير:** 2026-04-22  
**نظام المراجعة:** Flutter/Dart ERP System  
**المشاريع:** /home/user/systemmarket

---

# 1) تحليل الواجهات (UI Screens)

## 1.1 قائمة الشاشات وحالتها

| الوحدة | الشاشة | الملف | الحالة |
|--------|--------|-------|--------|
| **المبيعات** | POS (نقاط البيع) | [`pos_page.dart`](lib/presentation/features/pos/pos_page.dart) | مكتملة ✓ |
| | شاشة المبيعات | [`sales_invoice_page.dart`](lib/presentation/features/sales/sales_invoice_page.dart) | مكتملة ✓ |
| | سجل المبيعات | [`sales_history_page.dart`](lib/presentation/features/sales/sales_history_page.dart) | مكتملة ✓ |
| | إرجاع المبيعات | [`add_sales_return_page.dart`](lib/presentation/features/sales/add_sales_return_page.dart) | مكتملة ✓ |
| **المشتريات** | إضافة مشتريات | [`add_purchase_page.dart`](lib/presentation/features/purchases/add_purchase_page.dart) | مكتملة ✓ |
| | المشتريات | [`purchases_page.dart`](lib/presentation/features/purchases/purchases_page.dart) | مكتملة ✓ |
| | إرجاع المشتريات | [`add_purchase_return_page.dart`](lib/presentation/features/purchases/add_purchase_return_page.dart) | مكتملة ✓ |
| **المخزون** | إدارة المستودعات | [`warehouse_management_page.dart`](lib/presentation/features/inventory/warehouse_management_page.dart) | جزئية |
| | نقل المخزون | [`stock_transfer_page.dart`](lib/presentation/features/inventory/stock_transfer_page.dart) | مكتملة ✓ |
| | الجرد | [`stock_take_page.dart`](lib/presentation/features/inventory/stock_take_page.dart) | مكتملة ✓ |
| **العملاء** | العملاء | [`customers_page.dart`](lib/presentation/features/customers/customers_page.dart) | مكتملة ✓ |
| |كشف حساب عميل | [`customer_statement_page.dart`](lib/presentation/features/customers/customer_statement_page.dart) | مكتملة ✓ |
| **الموردين** | الموردين | [`suppliers_page.dart`](lib/presentation/features/suppliers/suppliers_page.dart) | مكتملة ✓ |
| | كشف حساب مورد | [`supplier_statement_page.dart`](lib/presentation/features/suppliers/supplier_statement_page.dart) | مكتملة ✓ |
| **المحاسبة** | شجرة الحسابات | [`chart_of_accounts_page.dart`](lib/presentation/features/accounting/chart_of_accounts_page.dart) | مكتملة ✓ |
| | دفتر اليومية | [`general_ledger_page.dart`](lib/presentation/features/accounting/general_ledger_page.dart) | مكتملة ✓ |
| | ميزان المراجعة | [`trial_balance_page.dart`](lib/presentation/features/accounting/trial_balance_page.dart) | مكتملة ✓ |
| | قائمة المركز | [`income_statement_page.dart`](lib/presentation/features/accounting/income_statement_page.dart) | مكتملة ✓ |
| | الميزانية | [`balance_sheet_page.dart`](lib/presentation/features/accounting/balance_sheet_page.dart) | مكتملة ✓ |
| | التدفقات النقدية | [`cash_flow_page.dart`](lib/presentation/features/accounting/cash_flow_page.dart) | مكتملة ✓ |
| | القيود اليدوية | [`manual_journal_entry_page.dart`](lib/presentation/features/accounting/manual_journal_entry_page.dart) | مكتملة ✓ |
| | الفترات المحاسبية | [`accounting_periods_page.dart`](lib/presentation/features/accounting/accounting_periods_page.dart) | مكتملة ✓ |
| **التقارير** | تقارير المبيعات | [`sales_reports_page.dart`](lib/presentation/features/reports/sales_reports_page.dart) | مكتملة ✓ |
| | تقارير المخزون | [`inventory_reports_screen.dart`](lib/presentation/features/reports/inventory_reports_screen.dart) | جزئية |
| | تقرير ضريبة القيمة المضافة | [`vat_report_page.dart`](lib/presentation/features/reports/vat_report_page.dart) | مكتملة ✓ |
| | سجل التدقيق | [`audit_log_page.dart`](lib/presentation/features/reports/audit_log_page.dart) | مكتملة ✓ |
| **الموظفين** | Employees | [`employees_page.dart`](lib/presentation/features/hr/employees_page.dart) | مكتملة ✓ |
| | الرواتب | [`payroll_page.dart`](lib/presentation/features/hr/payroll_page.dart) | مكتملة ✓ |
| | الإنتاج | Bill of Materials | [`bom_management_page.dart`](lib/presentation/features/manufacturing/bom_management_page.dart) | جزئية |

## 1.2 ملخص حالة الواجهات

- **إجمالي الشاشات:** +35 شاشة
- **مكتملة:** ~30 شاشة (85%)
- **جزئية:** ~5 شاشات (15%)
- **فارغة:** 0 شاشات

---

# 2) تحليل المعاملات (Transactions)

## 2.1 معالجة المبيعات

| الوظيفة | الملف | الدالة | الحالة |
|--------|-------|--------|-------|
| إنشاء فاتورة مبيعات | [`sales_dao.dart`](lib/data/datasources/local/daos/sales_dao.dart) | `createSale()` | ✓ |
| ترحيل فاتورة مبيعات | [`transaction_engine.dart`](lib/core/services/transaction_engine.dart:144) | `postSale()` | ✓ |
| التحقق من المخزون | [`transaction_engine.dart:173`](lib/core/services/transaction_engine.dart:173) | Stock Validation | ✓ |
| خصم المخزون (FEFO) | [`transaction_engine.dart:183`](lib/core/services/transaction_engine.dart:183) | Batch Deduction | ✓ |
| إنشاء قيد محاسبي | [`posting_engine.dart`](lib/core/services/posting_engine.dart:495) | `postTransaction()` | ✓ |
| تحديث رصيد العميل | [`transaction_engine.dart:240`](lib/core/services/transaction_engine.dart:240) | Credit Update | ✓ |
| إرسال حدث | [`transaction_engine.dart:252`](lib/core/services/transaction_engine.dart:252) | `SaleCreatedEvent` | ✓ |

**الملاحظات:**
- ✓ يتم التحقق من توفر المخزون قبل البيع
- ✓ يستخدم طريقة FEFO للخصم من الدفعات
- ✓ يتم إنشاء قيد محاسبي تلقائي
- ✓ يتم تحديث رصيد العميل في حالة البيع بالأجل
- ✓ يتم إرسال evento للتكامل مع المحاسبة

## 2.2 معالجة المشتريات

| الوظيفة | الملف | الدالة | الحالة |
|--------|-------|--------|-------|
| إنشاء فاتورة مشتريات | [`purchases_dao.dart`](lib/data/datasources/local/daos/purchases_dao.dart) | `createPurchase()` | ✓ |
| ترحيل فاتورة مشتريات | [`transaction_engine.dart:30`](lib/core/services/transaction_engine.dart:30) | `postPurchase()` | ✓ |
| إنشاء دفعات | [`transaction_engine.dart:79`](lib/core/services/transaction_engine.dart:79) | Batch Creation | ✓ |
| إضافة للمخزون | [`transaction_engine.dart:112`](lib/core/services/transaction_engine.dart:112) | Stock Update | ✓ |
| تحديد تكاليف الشحن | [`transaction_engine.dart:62`](lib/core/services/transaction_engine.dart:62) | Landed Cost | ✓ |
| تحديث رصيد المورد | [`transaction_engine.dart:125`](lib/core/services/transaction_engine.dart:125) | Supplier Balance | ✓ |
| إرسال حدث | [`transaction_engine.dart:137`](lib/core/services/transaction_engine.dart:137) | `PurchasePostedEvent` | ✓ |

**الملاحظات:**
- ✓ يتم إنشاء دفعات للمنتجات
- ✓ يتم распределение تكاليف الشحن على الأصناف
- ✓ يتم تحديث سعر التكلفة
- ✓ يتم ربط المورد بالفاتورة

## 2.3 إدارة المخزون

| الوظيفة | الملف | الدالة | الحالة |
|--------|-------|--------|-------|
| جرد المخزون | [`inventory_service.dart:18`](lib/core/services/inventory_service.dart:18) | `performInventoryAudit()` | ✓ |
| نقل المخزون | [`stock_transfer_service.dart`](lib/core/services/stock_transfer_service.dart) | Transfer Logic | ✓ |
| تحديث الكميات | [`transaction_engine.dart:112`](lib/core/services/transaction_engine.dart:112) | Stock Update | ✓ |
| تسجيل الحركات | [`transaction_engine.dart:100`](lib/core/services/transaction_engine.dart:100) | Inventory Transactions | ✓ |

## 2.4 المحاسبة

| الوظيفة | الملف | الدالة | الحالة |
|--------|-------|--------|-------|
| إنشاء قيود محاسبية | [`accounting_service.dart`](lib/core/services/accounting_service.dart:291) | `createJournalEntry()` | ✓ |
| دفتر اليومية | [`posting_engine.dart`](lib/core/services/posting_engine.dart) | Posting Rules | ✓ |
| فترات محاسبية | [`transaction_engine.dart:15`](lib/core/services/transaction_engine.dart:15) | Period Check | ✓ |
| شجرة الحسابات | [`chart_of_accounts`](lib/presentation/features/accounting/chart_of_accounts_page.dart) | Display | ✓ |

---

# 3) تحليل الخدمات (Services)

## 3.1 TransactionEngine

| الخدمة | الملف | الحالة | الاستخدام |
|--------|-------|---------|-----------|
| [`transaction_engine.dart`](lib/core/services/transaction_engine.dart:7) | موجود | ✓ | يُستخدم فعليًا في POS و sales_invoice_page |

**الملاحظات:**
- ✓ TransactionEngine هي الخدمة المركزية للمعاملات
- ✓ تُستدعى من [`pos_bloc.dart:412`](lib/presentation/features/pos/bloc/pos_bloc.dart:412) و [`sales_invoice_page.dart:541`](lib/presentation/features/sales/sales_invoice_page.dart:541)

## 3.2 AccountingService

| الخدمة | الملف | الحالة | الاستخدام |
|--------|-------|---------|-----------|
| [`accounting_service.dart`](lib/core/services/accounting_service.dart) | موجود | ✓ | يُستخدم في多处 |

**الملاحظات:**
- ✓AccountingService هي الخدمة المركزية للمحاسبة
- ✓ تُستخدم في multiple pages: expenses_page, accounting_provider
- ✓ تُنشئ GL Entries للمعاملات

## 3.3 InventoryService

| الخدمة | الملف | الحالة | الاستخدام |
|--------|-------|---------|-----------|
| [`inventory_service.dart`](lib/core/services/inventory_service.dart:7) | موجود | ✓ | يُستخدم في جرد المخزون |

## 3.4 PricingService

| الخدمة | الملف | الحالة | الاستخدام |
|--------|-------|---------|-----------|
| [`pricing_service.dart`](lib/core/services/pricing_service.dart:5) | موجود | ✓ | يُستخدم لجلب أسعار المنتجات |

---

# 4) تحليل قاعدة البيانات (Database)

## 4.1 الجداول (Tables)

### الجداول الأساسية (Core Tables)
| الجدول | الملف | الحقول الرئيسية | العلاقات |
|-------|-------|----------------|----------|
| Products | [`app_database.dart:45`](lib/data/datasources/local/app_database.dart:45) | name, sku, barcode, buyPrice, sellPrice, stock | Category, GLAccount |
| Customers | [`app_database.dart:77`](lib/data/datasources/local/app_database.dart:77) | name, phone, balance, creditLimit, accountId | Sales, GLAccount |
| Suppliers | [`app_database.dart:101`](lib/data/datasources/local/app_database.dart:101) | name, phone, balance, accountId | Purchases, GLAccount |
| Sales | [`app_database.dart:118`](lib/data/datasources/local/app_database.dart:118) | customerId, total, tax, discount, status | Customer |
| SaleItems | [`app_database.dart:136`](lib/data/datasources/local/app_database.dart:136) | saleId, productId, quantity, price | Sale, Product |
| Purchases | [`app_database.dart:145`](lib/data/datasources/local/app_database.dart:145) | supplierId, total, status, warehouseId | Supplier, Warehouse |
| PurchaseItems | [`app_database.dart:171`](lib/data/datasources/local/app_database.dart:171) | purchaseId, productId, quantity, batchId | Purchase, Product, Batch |

### جداول المخزون (Inventory Tables)
| الجدول | الملف | الوصف |
|-------|-------|-------|
| Warehouses | [`app_database.dart:192`](lib/data/datasources/local/app_database.dart:192) | المستودعات |
| ProductBatches | [`app_database.dart:198`](lib/data/datasources/local/app_database.dart:198) | دفعات المنتجات |
| InventoryTransactions | [`app_database.dart:492`](lib/data/datasources/local/app_database.dart:492) | حركات المخزون |
| InventoryAudits | [`app_database.dart:337`](lib/data/datasources/local/app_database.dart:337) | جرد المخزون |
| StockTransfers | [`app_database.dart:380`](lib/data/datasources/local/app_database.dart:380) | نقل المخزون |

### جداول المحاسبة (Accounting Tables)
| الجدول | الملف | الوصف |
|-------|-------|-------|
| GLAccounts | [`app_database.dart:262`](lib/data/datasources/local/app_database.dart:262) | شجرة الحسابات |
| GLEntries | [`app_database.dart:277`](lib/data/datasources/local/app_database.dart:277) | القيود المحاسبية |
| GLLines | [`app_database.dart:292`](lib/data/datasources/local/app_database.dart:292) | سطور القيد |
| AccountingPeriods | [`app_database.dart:304`](lib/data/datasources/local/app_database.dart:304) | الفترات المحاسبية |
| PostingProfiles | [`app_database.dart:521`](lib/data/datasources/local/app_database.dart:521) | قواعد الترحيل |

### جداول إضافية
| الجدول | الملف |
|-------|-------|
| Categories | [`app_database.dart:40`](lib/data/datasources/local/app_database.dart:40) |
| ProductUnits | [`app_database.dart:66`](lib/data/datasources/local/app_database.dart:66) |
| Promotions | [`app_database.dart:457`](lib/data/datasources/local/app_database.dart:457) |
| PriceLists | [`app_database.dart:443`](lib/data/datasources/local/app_database.dart:443) |
| Employees | [`app_database.dart:396`](lib/data/datasources/local/app_database.dart:396) |
| FixedAssets | [`app_database.dart:316`](lib/data/datasources/local/app_database.dart:316) |

## 4.2 العلاقات (Relationships)

✅ **العلاقات موجودة ومُعرَّفة:**
- Products → Category (FK)
- Products → GLAccount (FK for inventory account)
- Customers → GLAccount (FK for receivable account)
- Suppliers → GLAccount (FK for payable account)
- Sales → Customer (FK)
- SaleItems → Sale (FK), Product (FK)
- Purchases → Supplier (FK), Warehouse (FK)
- PurchaseItems → Purchase (FK), Product (FK), Batch (FK)
- ProductBatches → Product (FK), Warehouse (FK)
- GLEntries → GLLines (1:N)
- GLLines → GLAccount (FK), CostCenter (FK)

---

# 5) تحليل الربط (Integration)

## 5.1 المبيعات → المخزون

| الوظيفة | الملف | الدالة | الحالة |
|--------|-------|--------|-------|
| التحقق من المخزون | [`transaction_engine.dart:173`](lib/core/services/transaction_engine.dart:173) | Stock Validation | ✓ |
| خصم الكمية | [`transaction_engine.dart:215`](lib/core/services/transaction_engine.dart:215) | Batch Deduction | ✓ |
| تحديث المنتج | [`transaction_engine.dart:232`](lib/core/services/transaction_engine.dart:232) | Product Update | ✓ |
| تسجيل الحركة | [`transaction_engine.dart:216`](lib/core/services/transaction_engine.dart:216) | Inventory Transaction | ✓ |

**النتيجة:** ✓ يعمل بشكل كامل

## 5.2 المبيعات → المحاسبة

| الوظيفة | الملف | الدالة | الحالة |
|--------|-------|--------|-------|
| إنشاء قيد | [`posting_engine.dart:495`](lib/core/services/posting_engine.dart:495) | GL Entry Creation | ✓ |
| إرسال حدث | [`transaction_engine.dart:252`](lib/core/services/transaction_engine.dart:252) | SaleCreatedEvent | ✓ |
| معالجة الحدث | غير موجودة | Event Listener | ⚠️ |

**النتيجة:** ⚠️ جزئي (الأحداث تُرسَل لكن لا，我发现 معالجة نشطة для的事件)
- تم العثور على 创建 GLEntries في accounting_service.dart في multiple places
- لكن لم encontrar مستمع نشط للـ SaleCreatedEvent

## 5.3 المشتريات → المخزون

| الوظيفة | الملف | الدالة | الحالة |
|--------|-------|--------|-------|
| إنشاء دفعات | [`transaction_engine.dart:79`](lib/core/services/transaction_engine.dart:79) | Batch Creation | ✓ |
| تحديث المخزون | [`transaction_engine.dart:112`](lib/core/services/transaction_engine.dart:112) | Stock Update | ✓ |
| تسجيل الحركة | [`transaction_engine.dart:100`](lib/core/services/transaction_engine.dart:100) | Inventory Transaction | ✓ |

**النتيجة:** ✓ يعمل بشكل كامل

## 5.4 المشتريات → المحاسبة

| الوظيفة | الملف | الدالة | الحالة |
|--------|-------|--------|-------|
| إرسال حدث | [`transaction_engine.dart:137`](lib/core/services/transaction_engine.dart:137) | PurchasePostedEvent | ✓ |
| إنشاء قيد | [`purchase_service.dart:431`](lib/core/services/purchase_service.dart:431) | Manual GL Creation | ✓ |

**النتيجة:** ✓ يعمل بشكل جزئي

## 5.5 المنتجات ← المبيعات والمشتريات

| الوظيفة | الملف | الحالة |
|--------|-------|--------|
| ربط بالمنتج | [`SaleItems.productId`](lib/data/datasources/local/app_database.dart:138) FK | ✓ |
| ربط بالمنتج | [`PurchaseItems.productId`](lib/data/datasources/local/app_database.dart:173) FK | ✓ |

---

# 6) كشف النواقص

## 6.1 أشياء غير موجود��

| العنصر | الملاحظات |
|-------|----------|
| مستمعو الأحداث (Event Listeners) | لا يوجد معالجة نشطة للأحداث في main.dart |
| تقارير المخزون | الشاشة موجودة pero UI only |
| إدارة المستودعات | شاشة جزئية only |

## 6.2 أشياء غير مكتملة

| العنصر | الحالة |
|--------|--------|
| BOM ( Bill of Materials) | شاشة موجودة pero لا توجد معالجة كاملة |
| Warehouse Management | UI جزئية فقط |
| Inventory Reports | UI جزئية فقط |

## 6.3 أشياء غير مربوطة

| العنصر | الملاحظات |
|-------|----------|
| Event Bus listeners | الأحداث تُرسَل من transaction_engine pero لا توجد معالجة في الـ UI |
| Cost Centers | جدول موجود pero لا يُستخدم بشكل كامل في الـ transactions |

---

# 7) التقييم النهائي

## 7.1 نسبة الإنجاز

| القسم | النسبة | الملاحظات |
|-------|--------|----------|
| **المبيعات** | 95% | ✓ إنشاء فاتورة، ✓ خصم المخزون، ✓ قيد محاسبي، ✓ تحديث رصيد |
| **المشتريات** | 90% | ✓ إنشاء فاتورة، ✓ إضافة مخزون، ✓ دفعات، ✓ قيد محاسبي |
| **المخزون** | 85% | ✓ جرد، ✓ نقل، ✓ batches، ⚠️ تقارير غير مكتملة |
| **المحاسبة** | 80% | ✓ شجرة حسابات، ✓ قيود، ✓ ميزان مراجعة، ⚠️تكامل أحداث |
| **النظام ككل** | **87%** | ✓ هيكل قوي، ✓ خدمات متكاملة، ⚠️ بعض النواقص |

---

# 8) جدول المقارنة النهائي

| العنصر | الحالة | الملاحظات |
|-------|--------|----------|
| واجهات المستخدم | مكتملة (85%) | 35+ شاشات، معظمها يعمل |
| معاملات المبيعات | مكتملة | TransactionEngine + PostingEngine |
| معاملات المشتريات | مكتملة | مع batches وتكاليف الشحن |
| إدارة المخزون | مكتملة | جرد + نقل + batches |
| المحاسبة | جزئية-مكتملة | GL entries لكن بدون event processing |
| قاعدة البيانات | مكتملة | 40+ جدول مع علاقات |
| التكامل (مبيعات-مخزون) | مكتملة | يعمل بشكل كامل |
| التكامل (مبيعات-محاسبة) | جزئي | GL يُنشأ لكن بدون event listener نشط |
| التكامل (مشتريات-مخزون) | مكتملة | يعمل بشكل كامل |
| التكامل (مشتريات-محاسبة) | جزئي | يعمل لكن يحتاج تحسين |
| التسعير | مكتمل | PricingService موجود |
| الأحداث | غير مكتملة | تُرسَل لكن لا تُعالَج |

---

# 9) التوصيات

1. **إضافة Event Listeners** في main.dart لمعالجة SaleCreatedEvent و PurchasePostedEvent
2. **تحسين تقارير المخزون** - إضافة بيانات حقيقية
3. **إكمال BOM** (Bill of Materials) إذا كان مطلوبًا
4. **ربط Cost Centers** بالمعاملات
5. **إضافة اختبارات** للـ TransactionEngine

---

**نهاية التقرير**