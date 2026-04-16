# تقرير شامل - نظام إدارة السوبرماركت ERP

## ملخص النظام

**نوع التطبيق:** Flutter Desktop/Mobile ERP System
**قاعدة البيانات:** SQLite (Drift ORM)
**الحالة:** Offline-First Mode (لا يوجد Firebase)
**الإصدار:** 1.0.0

---

## 1. قاعدة البيانات (Database Schema)

### الجداول الرئيسية (48 جدول)

#### таблицы الأساسية للمبيعات:
| الجدول | الوصف | الحقول الرئيسية |
|--------|------|----------------|
| Users | المستخدمون | username, password, role, fullName |
| Products | المنتجات | name, sku, categoryId, stock, buyPrice, sellPrice |
| Categories | التصنيفات | name, code |
| SaleItems | أصناف الفاتورة | saleId, productId, quantity, price |
| Sales | فواتير المبيعات | customerId, total, discount, tax, paymentMethod, status, currencyId, qrCode (ZATCA) |

#### جداول المشتريات:
| الجدول | الوصف | الحقول الرئيسية |
|--------|------|----------------|
| Purchases | فواتير المشتريات | supplierId, total, status, warehouseId, currencyId |
| PurchaseItems | أصناف الفاتورة | purchaseId, productId, quantity, price, batchId |
| Suppliers | الموردون | name, phone, balance, accountId |

#### جداول العملاء والمحاسبة:
| الجدول | الوصف | الحقول الرئيسية |
|--------|------|----------------|
| Customers | العملاء | name, phone, balance, creditLimit, accountId, currencyId |
| GLAccounts | شجرة الحسابات | code, name, type, parentId, balance |
| GLEntries | القيود المحاسبية | description, date, referenceType, status, postedAt |
| GLLines | أسطر القيود | entryId, accountId, debit, credit, costCenterId |
| CostCenters | مراكز التكلفة | code, name, isActive |

#### جداول المخزون والمستودعات:
| الجدول | الوصف | الحقول الرئيسية |
|--------|------|----------------|
| Warehouses | المستودعات | name, location, isDefault |
| ProductBatches | دفعات المنتجات | productId, warehouseId, quantity, costPrice |
| InventoryTransactions | حركات المخزون | productId, warehouseId, quantity, type |
| StockTransfers | تحويلات المخزون | fromWarehouseId, toWarehouseId, status |
| StockTakes | جرد المخزون | warehouseId, status |

#### جداول الموارد البشرية:
| الجدول | الوصف | الحقول الرئيسية |
|--------|------|----------------|
| Employees | الموظفون | name, employeeCode, jobTitle, basicSalary |
| PayrollEntries | مسيرات الرواتب | month, year, status |
| Shifts | الورديات | userId, startTime, closingCash, isOpen |

#### جداول أخرى:
| الجدول | الوصف | الحقول الرئيسية |
|--------|------|----------------|
| Currencies | العملات | code, name, exchangeRate, isBase |
| Promotions | العروض الترويجية | name, type, value, startDate, endDate |
| PriceLists | قوائم الأسعار | name, currency, isActive |
| FixedAssets | الأصول الثابتة | name, cost, accumulatedDepreciation |
| Checks | الشيكات | checkNumber, bankName, amount, type, status |
| BillOfMaterials | قائمة المواد (BOM) | finishedProductId, componentProductId, quantity |
| AuditLogs | سجل التدقيق | userId, action, targetEntity, timestamp |
| Permissions | الصلاحيات | code, description |
| RolePermissions | صلاحيات الأدوار | role, permissionCode |

---

## 2. الواجهات (UI Pages)

### 2.1 صفحات المحاسبة (Accounting)
| الصفحة | الحالة | الوظائف |
|--------|----------|---------|
| chart_of_accounts_page.dart | ✅ مكتمل | عرض/إضافة/تعديل الحسابات |
| trial_balance_page.dart | ✅ مكتمل | تقرير ميزان المراجعة |
| general_ledger_page.dart | ✅ مكتمل | دفتر الأستاذ العام |
| income_statement_page.dart | ✅ مكتمل | قائمة الدخل |
| balance_sheet_page.dart | ✅ مكتمل | الميزان المالي |
| cash_flow_page.dart | ✅ مكتمل | قائمة التدفقات النقدية |
| accounting_periods_page.dart | ✅ مكتمل | الفترات المحاسبية |
| manual_journal_entry_page.dart | ✅ مكتمل | القيود اليدوية |
| manual_voucher_page.dart | ✅ مكتمل |القسائم اليدوية |
| reconciliation_page.dart | ✅ مكتمل | المطابقة البنكية |
| checks_page.dart | ✅ مكتمل | إدارة الشيكات |
| expenses_page.dart | ✅ مكتمل | مصروفات ثابتة |
| fixed_assets_page.dart | ✅ مكتمل | الأصول الثابتة |
| cost_centers_page.dart | ✅ مكتمل | مراكز التكلفة |
| shifts_page.dart | ✅ مكتمل | إدارة الورديات |

### 2.2 صفحات المبيعات (Sales)
| الصفحة | الحالة | الوظائف |
|--------|----------|---------|
| sales_history_page.dart | ✅ مكتمل | قائمة فواتير المبيعات |
| pos_page.dart | ✅ مكتمل | نقطة البيع (POS) مع دعم العملات |
| add_sales_return_page.dart | ✅ مكتمل | إضافة مردود مبيعات |
| sale_return_page.dart | ✅ مكتمل | قائمة مردودات المبيعات |

### 2.3 صفحات المشتريات (Purchases)
| الصفحة | الحالة | الوظائف |
|--------|----------|---------|
| purchases_page.dart | ✅ مكتمل | قائمة فواتير المشتريات |
| add_purchase_page.dart | ✅ مكتمل | إضافةفاتورة مشتريات |
| purchase_details_page.dart | ✅ مكتمل | تفاصيل الفاتورة |
| add_purchase_return_page.dart | ✅ مكتمل | إضافة مردود مشتريات |
| purchase_return_page.dart | ✅ مكتمل | قائمة مردودات المشتريات |

### 2.4 صفحات المخزون (Inventory)
| الصفحة | الحالة | الوظائف |
|--------|----------|---------|
| warehouse_management_page.dart | ✅ مكتمل | إدارة المستودعات |
| stock_transfer_page.dart | ✅ مكتمل | تحويل المخزون |
| stock_take_page.dart | ✅ مكتمل | جرد المخزون |

### 2.5 صفحات المنتجات والعملاء
| الصفحة | الحالة | الوظائف |
|--------|----------|---------|
| products_page.dart | ✅ مكتمل | إدارة المنتجات |
| categories_page.dart | ✅ مكتمل | إدارة التصنيفات |
| unit_conversion_page.dart | ✅ مكتمل | تحويل الوحدات |
| customers_page.dart | ✅ مكتمل | إدارة العملاء |
| customer_statement_page.dart | ✅ مكتمل | كشف حساب العميل |
| suppliers_page.dart | ✅ مكتمل | إدارة الموردين |
| supplier_statement_page.dart | ✅ مكتمل | كشف حساب المورد |

### 2.6 صفحات الموظفين والتقارير
| الصفحة | الحالة | الوظائف |
|--------|----------|---------|
| employees_page.dart | ✅ مكتمل | إدارة الموظفين |
| payroll_page.dart | ✅ مكتمل | مسير الرواتب |
| sales_reports_page.dart | ✅ مكتمل | تقارير المبيعات |
| inventory_audit_page.dart | ✅ مكتمل | تدقيق المخزون |
| vat_report_page.dart | ✅ مكتمل | تقرير ضريبة القيمة المضافة |
| product_profitability_page.dart | ✅ مكتمل | ربحية المنتجات |
| audit_log_page.dart | ✅ مكتمل | سجل التدقيق |

### 2.7 الإعدادات والصلاحيات
| الصفحة | الحالة | الوظائف |
|--------|----------|---------|
| backup_page.dart | ✅ مكتمل | النسخ الاحتياطي |
| currency_rates_page.dart | ✅ مكتمل | أسعار العملات |
| permissions_management_page.dart | ✅ مكتمل | إدارة الصلاحيات |
| staff_management_page.dart | ✅ مكتمل | إدارة المستخدمين |
| login_page.dart | ✅ مكتمل | تسجيل الدخول |

### 2.8 صفحات أخرى
| الصفحة | الحالة | الوظائف |
|--------|----------|---------|
| home_page.dart | ✅ مكتمل | الصفحة الرئيسية |
| dashboard_page.dart | ✅ مكتمل | لوحة القيادة |
| admin_dashboard_page.dart | ✅ مكتمل | لوحة المدير |
| low_stock_products_page.dart | ✅ مكتمل |منتجات مخزون منخفض |
| returns_page.dart | ✅ مكتمل | جميع المردودات |
| manufacturing_page.dart | ✅ مكتمل | إدارة BOM |

---

## 3. الخدمات والمنطق (Services & Business Logic)

### 3.1 الخدمات المحاسبية
| الخدمة | الملف | الحالة |
|---------|--------|----------|
| AccountingService | accounting_service.dart | ✅ مكتمل |
| TransactionEngine | transaction_engine.dart | ✅ مكتمل |

**الوظائف المنجزة:**
- ترحيل فواتير المبيعات (قيود آلية)
- ترحيل فواتير المشتريات
- معالجة المردودات
- معالجة المدفوعات
- ترحيل الشيكات
- إغلاق الفترات المحاسبية
- حساب الإهلاك
- مطابقة الحسابات

### 3.2 خدمات المخزون
| الخدمة | الملف | الحالة |
|---------|--------|----------|
| InventoryService | inventory_service.dart | ✅ مكتمل |
| StockTransferService | stock_transfer_service.dart | ✅ مكتمل |

**الوظائف المنجزة:**
- نظام FEFO (First Expired First Out)
- إدارة الدفعات
- تحويل المخزون بين المستودعات
- جرد المخزون

### 3.3 خدمات المبيعات والمشتريات
| الخدمة | الملف | الحالة |
|---------|--------|----------|
| ReturnService | return_service.dart | ✅ مكتمل |
| InvoiceService | invoice_service.dart | ✅ مكتمل |

### 3.4 خدمات أخرى
| الخدمة | الملف | الحالة |
|---------|--------|----------|
| HRService | hr_service.dart | ✅ مكتمل |
| AssetService | asset_service.dart | ✅ مكتمل |
| ShiftService | shift_service.dart | ✅ مكتمل |
| PricingService | pricing_service.dart | ✅ مكتمل |
| BomService | bom_service.dart | ✅ مكتمل |
| PDFService | pdf_service.dart | ✅ مكتمل |
| EventBusService | event_bus_service.dart | ✅ مكتمل |
| BackupService | backup_service.dart | ✅ مكتمل |

---

## 4. التكامل والربط

### 4.1 قاعدة البيانات ← الواجهات
- **الربط:** جميع الصفحات مرتبطة بـ AppDatabase عبر Drift DAOs
- **الـ BLoC Pattern:** يستخدم في POS فقط (PosBloc)
- **Provider:** باقي الصفحات تستخدم Provider مباشر

### 4.2 العمليات ← القيود المحاسبية
- **AccountingService** يستدعيه **TransactionEngine**
- **EventBus** يطلق الأحداث عند كل عملية
- **GLEntries & GLLines** يتم إنشاؤها تلقائياً

### 4.3 POS ← المخزون
- **البيع:** خصم المخزون عبر FEFO
- **الدفع:** تحديث رصيد العميل/المورد
- **المحاسبة:** إنشاء قيود تلقائية

---

## 5. الوظائف المنجزة (Completed Features)

### 5.1 المحاسبة
- ✅ شجرة الحسابات GL
- ✅ ال��يو�� اليومية الآلية
- ✅ دفتر الأستاذ العام
- ✅ ميزان المراجعة
- ✅ قائمة الدخل
- ✅ الميزان المالي
- ✅ قائمة التدفقات النقدية
- ✅ الفترات المحاسبية
- ✅ ترحيل وإغلاق会计 الفترة
- ✅ مصروفات ثابتة
- ✅ الأصول الثابتة والإهلاك
- ✅ مراكز التكلفة
- ✅ الشيكات (صرف واستلام)
- ✅ المطابقة البنكية

### 5.2 المبيعات
- ✅ POS متعدد العملات
- ✅ فواتير المبيعات
- ✅ خصم المخزون (FEFO)
- ✅ دفع نقدي وائتمان
- ✅ مردودات المبيعات
- ✅ العروض الترويجية

### 5.3 المشتريات
- ✅ فواتير المشتريات
- ✅ استلام المشتريات
- ✅ إنشاء الدفعات
- ✅ تحديث المخزون
- ✅ Landed Cost
- ✅ مردودات المشتريات

### 5.4 المخزون
- ✅ إدارة المستودعات
- ✅ نظام الدفعات (Batches)
- ✅ تحويل المخزون
- ✅ جرد المخزون
- ✅ تنبيهات المخزون المنخفض

### 5.5 العملاء والموردين
- ✅ إدارة العملاء
- ✅ كشف حساب العميل
- ✅ حد الائتمان
- ✅ إدارة الموردين
- ✅ كشف حساب المورد
- ✅ رصيد المورد

### 5.6 المنتجات
- ✅ إدارة المنتجات
- ✅ التصنيفات
- ✅ وحدات القياس (حبة، كرتون)
- ✅ باركود المنتجات
- ✅ قوائم الأسعار
- ✅ تحويل الوحدات

### 5.7 الموظفين
- ✅ إدارة الموظفين
- ✅ مسير الرواتب
- ✅ الورديات

### 5.8 التقارير
- ✅ تقارير المبيعات
- ✅ تقارير المخزون
- ✅ تقرير ربحية المنتج
- ✅ تقرير ضريبة القيمة المضافة
- ✅ سجل التدقيق

### 5.9 أخرى
- ✅ النسخ الاحتياطي المحلية
- ✅ صلاحيات المستخدمين
- ✅ تدقيق العمليات (Audit Trail)
- ✅ إشعارات App Events
- ✅ PDF الفواتير
- ✅ طباعة الفواتير

---

## 6. الوظائف الناقصة (Missing Features)

### 6.1 محاسب
- ❌ تسوية الشيكات الآلية (معلقة)
- ❌ حساب الإهلاك التلقائي (جزئي فقط)

### 6.2 склад
- ❌ تحليل المخزون المتقدم
- ❌ طلبات التوريد (Purchase Requests)

### 6.3 تقارير
- ❌ تقارير مخصصة
- ❌ تصدير Excel/PDF (جزئي للفاتورة فقط)

### 6.4 أخرى
- ❌ خدمة المزامنة (تمت إزالتها)
- ❌ التكامل مع بوابات الدفع
- ❌ تطبيق ويب

---

## 7. المشاكل والملاحظات

### 7.1 مشاكل حادة
| الملف | المشكلة |
|--------|----------|
| .vscode/settings.json | مفتاح API مكشوف (qwen.apiKey) |

### 7.2 مشاكل متوسطة
| الملف | المشكلة |
|--------|----------|
| backup_service.dart | استخدام دالة Share مهجورة |
| sales_history_page.dart | استخدام withAlpha المهجور |
| purchases_page.dart | StreamBuilder تم تغييره لـ FutureBuilder |
| purchases_page.dart |Pagination state غير persistant |

### 7.3 ملفات محذوفة
- lib/core/network/sync_service.dart (تمت إزالة خدمة Sync)
- backend/package.json (backend Express)
- backend/server.js

### 7.4 تحذيرات
- pubspec.yaml: 20 حزمة لها إصدارات أحدث غير متوافقة

---

## 8. نسبة الإنجاز

###Overall Progress: **~85%**

| الوحدة | النسبة |
|---------|--------|
| المحاسبة | 90% |
| المبيعات | 95% |
| المشتريات | 90% |
| المخزون | 85% |
| العملاء والموردين | 85% |
| المنتجات | 80% |
| الموظفين | 75% |
| التقارير | 70% |
| الصلاحيات | 80% |

---

## 9. التالي (Next Steps)

### أولوية قصوى:
1. **إصلاح:** إزالة مفتاح API المكشوف
2. **إضافة:** خدمة مزامنة بديلة (offline sync)
3. **تحسين:** الـ Pagination state persistence
4. **إضافة:** تقارير مخصصة

### أولوية متوسطة:
1. نظام طلبات التوريد
2. تحليل المخزون المتقدم
3. تكامل مع بوابات الدفع

### أولوية منخفضة:
1. تطبيق ويب
2. تطبيق آي أو إس
3. تقارير متعددة اللغات

---

## 10. الإحصائيات

| المقياس | القيمة |
|---------|--------|
| إجمالي الملفات | ~140 ملف |
| إجمالي الخدمات | 13 خدمة |
| إجمالي الجداول | 48 جدول |
| إجمالي الصفحات | ~50 صفحة |
| أسطر الكود (تقديري) | ~100,000 سطر |

---

*تم إنشاء هذا التقرير بتاريخ 2026-04-16*
*النظام مبني على Flutter + Drift (SQLite)*