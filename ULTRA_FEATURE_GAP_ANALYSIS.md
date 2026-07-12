# ULTRA FEATURE GAP ANALYSIS - FORENSIC AUDIT REPORT

**Date:** 2026-06-19
**Project:** SystemMarket Flutter ERP/POS
**Schema Veral Services:** 72+ | **Total Pages:** 62+ Routes | **Total Dart Files:** 370

---

## LEGEND

| Symbol | Meaning |
|--------|---------|
| ✅ | موجود ويعمل بالكامل |
| 🟡 | موجود جزئياً |
| ❌ | غير موجود |
| ⚠ | موجود بالشكل البرمجي لكن غير مربوط بالواجهة |
| ⚠UI | موجود بالواجهة لكن لا يعمل |
| ⚠BUG | موجود لكن يحتوي أخطاء منطقية |

---

# SECTION 1: نظام الصيانة (Maintenance System)

## الحالة العامة: ❌ غير موجود بالكامل

**النظام لا يحتوي على أي مكون من مكونات الصيانة. لا جداول، لا شاشات، لا خدمات، لا مسارات.**

| # | الميزة | الحالة | الملفات | الجداول | مستوى الاكتمال | المشكلة | المطلوب |
|---|--------|--------|---------|---------|---------------|---------|---------|
| 1 | استقبال الصيانة | ❌ | لا يوجد | لا يوجد | 0% | النظام بالكامل غير موجود | بناء كامل للوحدة |
| 2 | تسجيل بيانات العميل | ⚠ | `customers_dao.dart` | `Customers` | 20% | موجود لكن غير مربوط ببطاقة صيانة | ربط العميل بسجل الصيانة |
| 3 | استقبال عدة أجهزة | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد جدول أجهزة صيانة | إنشاء `ServiceTicketItems` |
| 4 | حالات الصيانة | ❌ | `app_enums.dart` | لا يوجد | 0% | `DocumentStatus` لا يحتوي حالات صيانة | إضافة حالات صيانة في Enum |
| 5 | تحديد نوع الصيانة | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد حقل نوع الصيانة | إضافة `maintenanceType` |
| 6 | موعد التسليم | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد حقل تاريخ التسليم | إضافة `estimatedDeliveryDate` |
| 7 | طباعة وصل الاستلام | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد قالب طباعة صيانة | بناء قالب PDF خاص بالصيانة |
| 8 | نسخة للعميل ونسخة للمحل | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد نظام نسخ متعدد | تطوير نظام النسخ |
| 9 | إشعارات SMS | ✅ | `communication_service.dart` | لا يوجد | 50% | الخدمة موجودة لكن غير مربوطة بالصيانة | ربط `sendSMS()` بحالات الصيانة |
| 10 | إشعارات WhatsApp | ✅ | `communication_service.dart` | لا يوجد | 50% | الخدمة موجودة لكن غير مربوطة بالصيانة | ربط `sendWhatsAppMessage()` بالصيانة |
| 11 | المبلغ المطلوب | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد حقل مبلغ الصيانة | إضافة `estimatedCost` و `actualCost` |
| 12 | تقارير الصيانة | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد تقارير صيانة | بناء تقارير الصيانة |
| 13 | البحث عن الصيانة | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد بحث | بناء بحث الصيانة |
| 14 | تحديث حالة الصيانة | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد تحديث حالات | بناء نظام تحديث الحالات |
| 15 | سجل حركات الصيانة | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد سجل حركات | إنشاء `ServiceTicketHistory` |

### الملفات المطلوبة لإنشاء وحدة الصيانة:
1. `lib/data/datasources/local/tables/maintenance_tables.dart` - جداول الصيانة
2. `lib/data/datasources/local/daos/maintenance_dao.dart` - عمليات قاعدة البيانات
3. `lib/domain/entities/service_ticket.dart` - كيان الصيانة
4. `lib/core/services/maintenance_service.dart` - خدمة الصيانة
5. `lib/presentation/features/maintenance/maintenance_page.dart` - الصفحة الرئيسية
6. `lib/presentation/features/maintenance/create_ticket_page.dart` - إنشاء تذكرة
7. `lib/presentation/features/maintenance/ticket_detail_page.dart` - تفاصيل التذكرة
8. `lib/presentation/features/maintenance/maintenance_provider.dart` - إدارة الحالة

### الجداول المطلوبة:
```
ServiceTickets: id, ticketNumber, customerId, deviceType, deviceBrand, deviceModel, 
  serialNumber, receivedDate, estimatedDeliveryDate, actualDeliveryDate, 
  status, maintenanceType, technicianId, estimatedCost, actualCost, notes

ServiceTicketItems: id, ticketId, description, quantity, unitCost, totalCost

ServiceTicketHistory: id, ticketId, oldStatus, newStatus, changedAt, changedBy, notes
```

### حالات الصيانة المطلوبة في `app_enums.dart`:
```
MaintenanceStatus: received, diagnosed, inProgress, waitingParts, 
  completed, delivered, cancelled
```

---

# SECTION 2: نظام طلبيات العملاء (Customer Orders)

## الحالة العامة: 🟡 موجود جزئياً (القاعدة موجودة، الواجهة غير موجودة)

| # | الميزة | الحالة | الملفات | الجداول | مستوى الاكتمال | المشكلة | المطلوب |
|---|--------|--------|---------|---------|---------------|---------|---------|
| 1 | تسجيل الطلبية | ⚠ | `sales_dao.dart:266` | `SalesOrders` | 30% | القاعدة والـ DAO موجودان لكن لا يوجد UI | بناء صفحة الطلبيات |
| 2 | اسم العميل | ⚠ | `sales_dao.dart` | `SalesOrders.customerId` | 30% | الحقل موجود في DB | عرضه في الواجهة |
| 3 | المنتج | ⚠ | `sales_dao.dart` | `SalesOrderItems` | 30% | جدول المنتجات موجود | ربطه بالواجهة |
| 4 | الكمية | ⚠ | `sales_dao.dart` | `SalesOrderItems.quantity` | 30% | الحقل موجود | ربطه بالواجهة |
| 5 | الملاحظات | ⚠ | `sales_dao.dart` | `SalesOrders.notes` | 30% | الحقل موجود | ربطه بالواجهة |
| 6 | حالات الطلبية | ⚠ | `sales_dao.dart:295` | `SalesOrders.status` | 30% | `updateSalesOrderStatus` موجود | ربطه بالواجهة |
| 7 | جاهز | ⚠ | لا يوجد UI | `status='INVOICED'` | 20% | الحالة موجودة في DB فقط | بناء واجهة |
| 8 | غير جاهز | ⚠ | لا يوجد UI | `status='ORDER'` | 20% | موجود في DB فقط | بناء واجهة |
| 9 | ملغي | ⚠ | لا يوجد UI | `status='CANCELLED'` | 20% | موجود في DB فقط | بناء واجهة |
| 10 | إشعار العميل عند الجاهزية | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد إشعار عند التحويل | ربط `CommunicationService` |
| 11 | تقارير الطلبيات | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد تقريرطلبيات | بناء تقرير الطلبيات |

### ما هو موجود:
- **قاعدة البيانات**: `SalesOrders` + `SalesOrderItems` جاهزة بالكامل
- **DAO**: `createSalesOrder()`, `updateSalesOrderStatus()`, `deleteSalesOrder()`, `getAllSalesOrders()`, `getSalesOrdersByCustomer()`, `getSalesOrdersByStatus()`
- **حالات**: `QUOTATION, ORDER, DELIVERED, INVOICED, CANCELLED`

### ما هو مفقود:
- صفحة عرض الطلبيات (`sales_orders_page.dart`)
- صفحة إنشاء طلبية جديدة
- صفحة تعديل الطلبية
- تحويل الطلبية إلى فاتورة بيع
- إشعارات الجاهزية

---

# SECTION 3: نظام المشتريات (Purchases System)

## الحالة العامة: ✅ موجود بالكامل مع بعض النقص

| # | الميزة | الحالة | الملفات | الجداول | مستوى الاكتمال | المشكلة | المطلوب |
|---|--------|--------|---------|---------|---------------|---------|---------|
| 1 | إضافة منتجات من شاشة الشراء | ✅ | `add_purchase_page.dart:337-372` | `Products` | 100% | يعمل بشكل كامل | - |
| 2 | إضافة مورد من شاشة الشراء | 🟡 | `add_purchase_page.dart:268` | `Suppliers` | 40% | فقط الاسم، لا هاتف أو عنوان | إضافة حقول إضافية |
| 3 | الشراء نقد | ✅ | `add_purchase_page.dart:284` | `Purchases.isCredit=false` | 100% | يعمل | - |
| 4 | الشراء آجل | ✅ | `add_purchase_page.dart:284` | `Purchases.isCredit=true` | 100% | يعمل مع تحديث رصيد المورد | - |
| 5 | الشراء بطاقة | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد خيار بطاقة في المشتريات | إضافة `PaymentMethod.bank` |
| 6 | آخر سعر شراء | ✅ | `purchases_dao.dart:132-175` | `PurchaseItems` | 90% | يوجد لكن لا يظهر في الواجهة | عرضه في `PurchaseItemRow` |
| 7 | متوسط التكلفة | ✅ | `purchase_provider.dart:424` | `PurchaseItems` | 85% | يعمل عبر `_calculateAverageCost` | - |
| 8 | آخر تكلفة | ✅ | `products.buyPrice` | `Products` | 100% | يحدث عند GRN و TransactionEngine | - |
| 9 | فواتير المشتريات | ✅ | `purchases_page.dart` | `Purchases` | 100% | CRUD كامل | - |
| 10 | طباعة الفواتير | 🟡 | `purchase_details_page.dart:253-304` | لا يوجد | 30% | PDF نصي فقط، لا تصميم احترافي | بناء قالب PDF احترافي |
| 11 | حساب المورد | ✅ | `suppliers_dao.dart:145` | `SupplierPayments` | 100% | كشف حساب كامل | - |
| 12 | طلب شراء | ✅ | `purchase_orders_page.dart` | `PurchaseOrders` | 85% | CRUD + تحويل لفاتورة | - |
| 13 | استيراد طلب شراء | 🟡 | `purchase_converter.dart` | `PurchaseOrders` | 50% | تحويل فقط، لا CSV/Excel | إضافة استيراد ملفات |
| 14 | تحديث المخزون تلقائياً | ✅ | `grn_service.dart:15-106` | `ProductBatches, InventoryTransactions` | 100% | يعمل عبر GRN + batch tracking | - |
| 15 | القيود المحاسبية | ✅ | `posting_engine.dart:164-223` | `GLEntries, GLLines` | 100% | قيد مزدوج مع Posting Profiles | - |

### المشاكل المكتشفة:
1. **طباعة الفواتير**: PDF نصي فقط (`StringBuffer`) بدون تصميم احترافي ولا دعم طابعة حرارية
2. **إضافة مورد من شاشة الشراء**: فقط الاسم (`EntityPicker` inline) بدون باقي الحقول
3. **لا يوجد خيار بطاقة/تحويل بنكي** في المشتريات
4. **لا يوجد استيراد CSV/Excel** للطلبيات (التحويل فقط)
5. **لا يوجد سبب إرجاع** (reason codes) في مرتجعات المشتريات

---

# SECTION 4: نظام المبيعات (Sales System)

## الحالة العامة: ✅ موجود بالكامل مع بعض النقص

| # | الميزة | الحالة | الملفات | الجداول | مستوى الاكتمال | المشكلة | المطلوب |
|---|--------|--------|---------|---------|---------------|---------|---------|
| 1 | إضافة عميل أثناء البيع | ✅ | `quick_customer_service.dart` | `Customers` | 90% | يعمل في POS فقط، لا في فاتورة البيع | ربط `QuickCustomerService` بـ `sales_invoice_page` |
| 2 | صور المنتجات | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد حقل صورة في Products | إضافة `imageUrl` + عرض في الواجهة |
| 3 | البيع السريع | ✅ | `pos_page.dart` | `Sales` | 100% | POS كامل مع BLoC | - |
| 4 | البيع النقدي | ✅ | `pos_bloc.dart`, `checkout_dialog.dart` | `Sales.isCredit=false` | 100% | يعمل مع فتح الوردية | - |
| 5 | البيع الآجل | ✅ | `pos_bloc.dart:600-610` | `Sales.isCredit=true` | 100% | مع فحص الحد الائتماني | - |
| 6 | البيع بالبطاقة | ✅ | `checkout_dialog.dart:113` | `PaymentMethod.bank` | 100% | يعمل | - |
| 7 | منع البيع عند نفاد الكمية | ✅ | `transaction_engine.dart:253-257` | لا يوجد | 100% | يتحقق عند Posting | - |
| 8 | إخفاء التكلفة | ⚠ | `app_config_service.dart:19` | `AppConfigTable` | 30% | المفتاح موجود لكن غير مربوط بالواجهة | ربط `hideSalePrices` بـ UI |
| 9 | عرض سعر | ⚠ | `sales_dao.dart:266` | `SalesOrders` | 20% | الجدول موجود لكن لا يوجد UI | بناء صفحة عروض الأسعار |
| 10 | استيراد عرض سعر | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد استيراد | بناء نظام استيراد |
| 11 | البحث الذكي | 🟡 | `pos_bloc.dart:361`, `sales_item_row.dart:40` | لا يوجد | 50% | POS search معطّل (commented out) | تفعيل البحث اللحظي |
| 12 | البيع بالتجزئة | ✅ | `pos_page.dart` | `SaleItems` | 100% | بيع قطعة واحدة | - |
| 13 | البيع بالوحدات | ✅ | `cart_widget.dart:379-428`, `ProductUnits` | `ProductUnits` | 100% | اختيار الوحدة + تحويل | - |
| 14 | البيع بالكرتون | ✅ | `packaging_engine.dart` | `ProductUnits` | 100% | تحويل تلقائي + تفكيك | - |
| 15 | البيع بالحبة | ✅ | `cart_widget.dart` | `SaleItems.unitName='حبة'` | 100% | الوحدة الافتراضية | - |
| 16 | القيود المحاسبية | ✅ | `posting_engine.dart:67-138` | `GLEntries, GLLines` | 100% | قيد مزدوج + COGS + VAT | - |

### المشاكل المكتشفة:
1. **صور المنتجات**: غير موجودة بالكامل - `PosProductCard` يستخدم `Icons.inventory_2` فقط
2. **البحث الذكي في POS**: معطّل (`product_search_widget.dart:32` - سطر معلّق)
3. **إخفاء التكلفة**: المفتاح `hideSalePrices` موجود في Config لكن لا يستخدم في الواجهة
4. **عروض الأسعار**: قاعدة البيانات والـ DAO جاهزة لكن لا يوجد UI
5. **Quick Customer**: يعمل في POS فقط، لا في `sales_invoice_page.dart`
6. **ZATCA**: QR Code بصيغة SVG بدائية وليس TLV كامل

---

# SECTION 5: نظام الموردين (Suppliers)

## الحالة العامة: ✅ موجود بالكامل مع نقص في الطباعة

| # | الميزة | الحالة | الملفات | الجداول | مستوى الاكتمال | المشكلة | المطلوب |
|---|--------|--------|---------|---------|---------------|---------|---------|
| 1 | إضافة مورد | ✅ | `add_edit_supplier_dialog.dart` | `Suppliers` | 100% | CRUD كامل مع GL Account تلقائي | - |
| 2 | كشف حساب المورد | ✅ | `supplier_statement_page.dart` | `Suppliers` | 100% | مشتريات + مدفوعات + مرتجعات | - |
| 3 | سند قبض | ✅ | `manual_voucher_page.dart` | `CashboxTransactions` | 100% | سند قبض عام | - |
| 4 | سند صرف | ✅ | `add_supplier_payment_page.dart` | `SupplierPayments` | 100% | سند صرف للمورد | - |
| 5 | تسديد الفواتير الآجلة | ✅ | `supplier_payment_dialog.dart` | `PurchasePaymentLinks` | 100% | تخصيص الدفعة على فواتير محددة | - |
| 6 | إرسال رسائل للمورد | ✅ | `communication_service.dart` | لا يوجد | 100% | هاتف + WhatsApp | - |
| 7 | طباعة كشف الحساب | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد زر طباعة في `supplier_statement_page.dart` | إضافة طباعة PDF |

### المشاكل:
1. **لا توجد طباعة كشف حساب المورد** - لا يوجد زر طباعة في الصفحة
2. **لا توجد طباعة سند القبض/الصرف** بعد الحفظ
3. **إضافة مورد من شاشة الشراء**: فقط الاسم بدون باقي الحقول

---

# SECTION 6: نظام العملاء (Customers)

## الحالة العامة: ✅ موجود بالكامل مع نقص في الطباعة

| # | الميزة | الحالة | الملفات | الجداول | مستوى الاكتمال | المشكلة | المطلوب |
|---|--------|--------|---------|---------|---------------|---------|---------|
| 1 | إضافة عميل | ✅ | `add_edit_customer_dialog.dart` | `Customers` | 100% | CRUD كامل مع GL Account تلقائي + دعم أنواع (تجزئة/جملة/VIP) | - |
| 2 | كشف حساب العميل | ✅ | `customer_statement_page.dart` | `Customers` | 100% | مبيعات + مدفوعات + مرتجعات + رصيد متحرك | - |
| 3 | سند قبض | ✅ | `customer_payment_dialog.dart` | `CustomerPayments` | 100% | تخصيص الدفعة على فواتير | - |
| 4 | سند صرف | ✅ | `manual_voucher_page.dart` | `CashboxTransactions` | 100% | سند صرف عام | - |
| 5 | تسديد المبيعات الآجلة | ✅ | `customer_payment_dialog.dart` | `CustomerPaymentLinks` | 100% | تخصيص الدفعة على فواتير محددة | - |
| 6 | إرسال رسائل للعميل | ✅ | `customer_trailing_widgets.dart` | لا يوجد | 100% | هاتف + WhatsApp | - |
| 7 | طباعة كشف الحساب | ⚠UI | `customer_statement_page.dart:32-38` | لا يوجد | 10% | الزر موجود لكن `onPressed` فارغ بتعليق "مستقبلاً" | تنفيذ الدالة |

### المشاكل:
1. **طباعة كشف حساب العميل**: الزر موجود لكن `onPressed` فارغ (سطر 32-38)
2. **لا توجد طباعة سند القبض** بعد حفظ الدفعة
3. **لا يوجد صفحة مستقلة** "إضافة دفعة عميل" (موجود فقط في الـ dialog)

---

# SECTION 7: نظام المخزون (Inventory System)

## الحالة العامة: ✅ موجود بالكامل مع بعض النقص

| # | الميزة | الحالة | الملفات | الجداول | مستوى الاكتمال | المشكلة | المطلوب |
|---|--------|--------|---------|---------|---------------|---------|---------|
| 1 | المنتجات | ✅ | `products_page.dart`, `products_dao.dart` | `Products` | 95% | CRUD + بحث + pagination | BUG: تعديل المنتج لا يحفظ |
| 2 | التصنيفات | ✅ | `categories_page.dart` | `Categories` | 100% | CRUD + حماية الحذف | - |
| 3 | Excel Import | 🟡 | `data_import_service.dart` | لا يوجد | 30% | CSV فقط، `.xlsx` يُقبل لكن يفشل | دعم Excel حقيقي (.xlsx) |
| 4 | Excel Export | ⚠ | `export_service.dart` | لا يوجد | 20% | `ExportFormat.excel` يُ exporting CSV فقط | بناء XLSX حقيقي |
| 5 | توليد باركود | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد توليد باركود | بناء خدمة توليد EAN-13/Code128 |
| 6 | قراءة باركود | ✅ | `barcode_scanner_service.dart` | لا يوجد | 60% | مسح كاميرا عبر `mobile_scanner` | تطوير `scanFromCamera()` |
| 7 | طباعة باركود | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد طباعة ملصقات | بناء نظام طباعة ملصقات |
| 8 | نقل تصنيف | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد نقل جماعي | بناء "نقل من تصنيف X إلى Y" |
| 9 | تصفير الكميات | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد زر تصفير | بناء ميزة تصفير المخزون |
| 10 | أول المدة | 🟡 | `add_edit_product_dialog.dart:132-148` | `InventoryTransactions` | 30% | فقط عند إنشاء منتج جديد، لا دفعة جماعية | بناء شاشة أرصدة افتتاحية جماعية |
| 11 | جرد المخزون | ✅ | `stock_take_page.dart` | `StockTakes, StockTakeItems` | 100% | workflow كامل مع تسويات محاسبية | - |
| 12 | حركة المخزون | ✅ | `stock_movement_dao.dart` | `StockMovements, InventoryTransactions` | 100% | تقرير حركة باليوم والمخزن | - |
| 13 | التوريد والصرف | ✅ | `stock_transfer_page.dart`, `stock_transfer_service.dart` | `StockTransfers` | 100% | نقل بين مخازن مع batch tracking | - |

### المشاكل الحرجة:
1. **BUG في تعديل المنتج**: `add_edit_product_dialog.dart:119` - دالة `_saveProduct()` لا تحفظ عند التعديل (فقط الإنشاء)
2. **لا يوجد توليد/طباعة باركود**: لا خدمة توليد ولا طباعة ملصقات
3. **Excel Import وهمي**: يقبل `.xlsx` لكن لا يقرأها (CSV فقط)
4. **لا يوجد تصفير جماعي** للمخزون
5. **لا توجد أرصدة افتتاحية جماعية** (فقط عند إنشاء منتج جديد)
6. **كود مكرر**: النقل بين المخازن مُ implement في 3 أماكن مختلفة

---

# SECTION 8: نظام الصناديق (Cash Management)

## الحالة العامة: ✅ موجود بالكامل مع نقص في صندوق البطاقة والعملات المتعددة

| # | الميزة | الحالة | الملفات | الجداول | مستوى الاكتمال | المشكلة | المطلوب |
|---|--------|--------|---------|---------|---------------|---------|---------|
| 1 | صندوق النقدية | ✅ | `cash_management_page.dart` | `CashboxTransactions` | 100% | IN/OUT مع GL posting | - |
| 2 | صندوق الخزينة | ✅ | `transfers_page.dart` | `FinancialTransfers` | 100% | تحويل بين أي حسابين GL | - |
| 3 | صندوق البطاقة | ❌ | لا يوجد | لا يوجد | 0% | لا يوجد صندوق منفصل للبطاقة | بناء `CardBoxPage` |
| 4 | الأرصدة الافتتاحية | ✅ | `shifts_page.dart` | `Shifts.openingCash` | 100% | فتح وردية مع رصيد افتتاحي | - |
| 5 | إقفال الوردية | ✅ | `financial_closing_service.dart:423-486` | `Shifts` | 100% | إقفال مع فحص差额 وقيد محاسبي | - |
| 6 | التحويل بين الصناديق | ✅ | `transfers_page.dart`, `transfer_service.dart` | `FinancialTransfers` | 100% | تحويل + عمولة + GL posting | - |
| 7 | التحويل متعدد العملات | ❌ | لا يوجد | `Currencies, ExchangeRates` | 10% | الجداول موجودة لكن لا يوجد منطق تحويل | بناء منطق تحويل العملات |
| 8 | كشف حركة الصندوق | ✅ | `cashbox_dao.dart:10` | `CashboxTransactions` | 100% | Stream تاريخي مرتب | - |

### المشاكل:
1. **لا يوجد صندوق بطاقة منفصل** - المعاملات البنكية تظهر كأي حساب GL
2. **التحويل متعدد العملات**: `currencyId` و `exchangeRate` موجودان في DB لكن لا يُستخدمان في `TransferService` أو `PostingEngine`
3. **لا يوجد حساب التحويلات** المتعددة العملات

---

# SECTION 9: إدارة المستخدمين والصلاحيات

## الحالة العامة: ✅ موجود مع تضارب في أدوار المستخدمين

| # | الميزة | الحالة | الملفات | الجداول | مستوى الاكتمال | المشكلة | المطلوب |
|---|--------|--------|---------|---------|---------------|---------|---------|
| 1 | المستخدمين | ✅ | `staff_management_page.dart` | `Users` | 100% | CRUD كامل | - |
| 2 | كلمات المرور | ✅ | `auth_provider.dart`, `staff_management_page.dart` | `Users` | 90% | BCrypt hashing | BUG: `user_roles_page.dart` يحفظ plain text |
| 3 | المدير | ✅ | `user_role.dart` | `Users.role` | 100% | admin/manager/cashier | - |
| 4 | المستخدم العادي | ✅ | `user_role.dart` | `Users.role` | 100% | cashier يمثل المستخدم العادي | - |
| 5 | صلاحية الإضافة | ✅ | `permission_service.dart` | `Permissions, RolePermissions` | 100% | POST_SALE, POST_PURCHASE, etc. | - |
| 6 | صلاحية الحذف | ✅ | `advanced_permission_service.dart` | `RolePermissions` | 100% | SALE_DELETE, MANAGE_USERS, etc. | - |
| 7 | صلاحية التعديل | ✅ | `advanced_permission_service.dart` | `RolePermissions` | 100% | SALE_EDIT, PURCHASE_EDIT_PRICE, etc. | - |
| 8 | صلاحية العرض | ✅ | `permission_service.dart` | `RolePermissions` | 100% | VIEW_REPORTS, VIEW_FINANCIALS, etc. | - |
| 9 | صلاحيات الشاشات | 🟡 | `access_guard.dart` | لا يوجد | 40% | Route-based فقط، لا يوجد per-screen | تطوير per-screen permissions |
| 10 | صلاحيات التقارير | 🟡 | `permission_service.dart` | `RolePermissions` | 40% | `VIEW_REPORTS` واحد فقط | تقسيم حسب نوع التقرير |

### المشاكل الحرجة:
1. **تضارب الأدوار**: 4 أماكن تُعرّف الأدوار بشكل مختلف:
   - `UserRole` enum: admin, manager, cashier
   - Staff Management: admin, manager, cashier
   - User Roles Page: Admin, Manager, Cashier, Accountant
   - Permissions Management: Admin, Manager, Cashier, User
   - Settings Permissions: admin, cashier, manager, viewer
2. **ثغرة أمنية**: `user_roles_page.dart:288` يحفظ كلمة المرور بدون BCrypt hashing
3. **3 صفحات صلاحيات مكررة** بأسماء permission مختلفة (underscore vs dot notation)
4. **لا توجد صلاحيات per-screen** - فقط route-based عبر `AccessGuard`
5. **لا توجد صلاحيات per-report** - فقط `VIEW_REPORTS` واحد
6. **Hard delete للمستخدمين** مقابل soft delete للعملاء/الموردين

---

# SECTION 10: التقارير (Reports)

## الحالة العامة: 🟡 موجود جزئياً - تقارير أساسية مع نقص كبير

| # | الميزة | الحالة | الملفات | مستوى الاكتمال | المشكلة |
|---|--------|--------|---------|---------------|---------|
| 1 | تقارير الصيانة | ❌ | لا يوجد | 0% | غير موجود بالكامل |
| 2 | المبيعات | ✅ | `sales_reports_page.dart` | 80% | ملخص + رسم بياني + أعلى المنتجات |
| 3 | الأرباح | ✅ | `profitability_report_page.dart`, `product_profitability_page.dart` | 85% | إجمالي + تفصيلي بالمنتج |
| 4 | المشتريات | ❌ | لا يوجد | 0% | لا يوجد تقرير مشتريات مستقل |
| 5 | العملاء | ❌ | لا يوجد | 0% | لا يوجد تقرير عملاء (فقط Aging) |
| 6 | الموردين | 🟡 | `supplier_performance_page.dart` | 40% | تقرير أداء بسيط فقط |
| 7 | المخزون | ✅ | `inventory_reports_screen.dart` + widgets | 90% | قيمة + تنبيه + حركات + دفعات |
| 8 | الصناديق | ❌ | لا يوجد | 0% | لا يوجد تقرير صناديق |
| 9 | المحاسبة | ✅ | `accounting/` (صفحات مستقلة) | 90% | ميزان + ميزانية + أرباح/خسائر + تدفق نقدي |
| 10 | المصروفات | ✅ | `expenses_by_center_page.dart` | 70% | بالمركز + فلتر زمني |
| 11 | الإيرادات | 🟡 | جزئياً في `sales_reports_page.dart` | 30% | لا يوجد تقرير إيرادات مستقل |
| 12 | التوريد والصرف | ❌ | لا يوجد | 0% | لا يوجد تقرير توريد وصرف |
| 13 | الرسوم البيانية | 🟡 | `admin_dashboard_page.dart` | 50% | fl_chart في Dashboard فقط |
| 14 | Dashboard | ✅ | `dashboard_page.dart`, `admin_dashboard_page.dart`, `dynamic_dashboard.dart` | 80% | 3 أنواع Dashboard |
| 15 | الفلاتر الزمنية | 🟡 | `period_filter_widget.dart` | 50% | يوجد widget مشترك لكن لا يُستخدم في كل التقارير |

### المشاكل:
1. **لا يوجد تقرير مشتريات مستقل** - البيانات موجودة لكن لا تظهر في صفحة تقارير
2. **لا يوجد تقرير عملاء** - فقط Aging Report يغطي العملاء
3. **لا يوجد تقرير صناديق** - لا تحليل حركات الصندوق
4. **`ChartService` غير مسجل في DI** - كود ميت
5. **`PaginatedListMixin` كود ميت** - مُعرّف لكن لا يُستخدم
6. **لا يوجد `financial_reports_service.dart`** - الملف غير موجود
7. **N+1 query** في `DashboardService.getTopProducts()`
8. **FutureBuilder anti-pattern** في صفحات التقارير

---

# SECTION 11: تحسينات النظام

## الحالة العامة: 🟡 بعض الميزات موجودة مع نقص كبير في الأداء

| # | الميزة | الحالة | الملفات | مستوى الاكتمال | المشكلة |
|---|--------|--------|---------|---------------|---------|
| 1 | إعداد العلامة العشرية | 🟡 | `currencies.decimalPlaces` | 40% | لكل عملة على حدة، لا يوجد global setting |
| 2 | البحث الذكي | 🟡 | `command_palette.dart`, `quick_customer_service.dart` | 40% | Command Palette + بحث عملاء فقط |
| 3 | سرعة الأداء | 🟡 | لا يوجد ملف محدد | 30% | لا يوجد caching + N+1 queries + FutureBuilder |
| 4 | Lazy Loading | 🟡 | `pagination_mixin.dart` | 20% | Mixin موجود لكن لا يُستخدم (dead code) |
| 5 | Pagination | ✅ | 5 صفحات | 70% | يدوياً في products/customers/suppliers/sales/purchases |
| 6 | التحكم بالواجهة الرئيسية | ❌ | لا يوجد | 0% | لا يوجد إعادة ترتيب أو إخفاء |
| 7 | ترتيب البطاقات | ❌ | لا يوجد | 0% | Layout ثابت في `home_page.dart` |
| 8 | إخفاء العناصر | ❌ | لا يوجد | 0% | لا يوجد تخصيص للمستخدم |
| 9 | استقرار التطبيق | 🟡 | `injection_container.dart:107-144` | 40% | استرداد تلف قاعدة البيانات فقط |
| 10 | استهلاك الذاكرة | ❌ | لا يوجد | 0% | لا يوجد مراقبة ذاكرة |
| 11 | استهلاك المعالج | ❌ | لا يوجد | 0% | لا يوجد مراقبة معالج |
| 12 | ارتفاع الحرارة | ❌ | لا يوجد | 0% | لا يوجد مراقبة حرارة |
| 13 | الأخطاء الحرجة | ❌ | لا يوجد | 0% | لا يوجد Crash Reporting (Crashlytics/Sentry) |

### المشاكل الأدائية:
1. **لا يوجد caching** - كل طلب يقرأ من قاعدة البيانات مباشرة
2. **N+1 queries** في DashboardService.getTopProducts() - loop query لكل فاتورة
3. **FutureBuilder في widget tree** - DB queries مباشرة في واجهات التقارير
4. **PaginatedListMixin ميت الكود** - مُعرّف لكن لا يُستخدم
5. **DashboardProvider يجلب كل البيانات** عند التهيئة
6. **لا يوجد crash reporting** - لا Crashlytics ولا Sentry

---

# SECTION 12: التحليل النهائي

## نسب الاكتمال حسب القسم

| القسم | نسبة الاكتمال | عدد الميزات المتوفرة/الكل |
|-------|--------------|--------------------------|
| **نظام الصيانة** | **0%** | 0/15 |
| **طلبيات العملاء** | **25%** | 3/11 (قاعدة فقط) |
| **نظام المشتريات** | **80%** | 12/15 |
| **نظام المبيعات** | **82%** | 13/16 |
| **نظام الموردين** | **86%** | 6/7 |
| **نظام العملاء** | **86%** | 6/7 |
| **نظام المخزون** | **72%** | 9/13 |
| **نظام الصناديق** | **75%** | 6/8 |
| **المستخدمين والصلاحيات** | **70%** | 7/10 |
| **التقارير** | **35%** | 5/15 |
| **تحسينات النظام** | **20%** | 2/13 |

## النسب الإجمالية

| المقياس | النسبة |
|---------|--------|
| **نسبة اكتمال النظام الكلية** | **55%** |
| **نسبة اكتمال الصيانة** | **0%** |
| **نسبة اكتمال المبيعات** | **82%** |
| **نسبة اكتمال المشتريات** | **80%** |
| **نسبة اكتمال المخزون** | **72%** |
| **نسبة اكتمال المحاسبة** | **88%** |
| **نسبة اكتمال التقارير** | **35%** |

---

# TOP 50 MISSING FEATURES

| # | الميزة | الأولوية | القسم |
|---|--------|---------|-------|
| 1 | وحدة الصيانة بالكامل | Critical | صيانة |
| 2 | صور المنتجات | Critical | مبيعات |
| 3 | توليد وطباعة الباركود | Critical | مخزون |
| 4 | صفحة طلبيات العملاء (UI) | High | طلبيات |
| 5 | صفحة عروض الأسعار (UI) | High | مبيعات |
| 6 | تقرير المشتريات المستقل | High | تقارير |
| 7 | تقرير العملاء | High | تقارير |
| 8 | تقرير الصناديق | High | تقارير |
| 9 | صندوق البطاقة المنفصل | High | صناديق |
| 10 | التحويل متعدد العملات | High | صناديق |
| 11 | Excel Import/Export حقيقي (.xlsx) | High | مخزون |
| 12 | طباعة كشف حساب المورد | High | موردين |
| 13 | طباعة كشف حساب العميل | High | عملاء |
| 14 | طباعة سند القبض/الصرف بعد الحفظ | High | محاسبة |
| 15 | Crash Reporting | High | أداء |
| 16 | Caching Layer | High | أداء |
| 17 | صفحة أرصدة افتتاحية جماعية | High | مخزون |
| 18 | تصفير المخزون | Medium | مخزون |
| 19 | نقل تصنيف جماعي | Medium | مخزون |
| 20 | الشراء بطاقة/تحويل بنكي | Medium | مشتريات |
| 21 | بحث ذكي للمنتجات والموردين | Medium | عامة |
| 22 | تقرير توريد وصرف | Medium | تقارير |
| 23 | تقرير إيرادات مستقل | Medium | تقارير |
| 24 | تقسيم صلاحيات التقارير | Medium | صلاحيات |
| 25 | صلاحيات per-screen | Medium | صلاحيات |
| 26 | ترتيب وإخفاء عناصر الواجهة الرئيسية | Medium | واجهة |
| 27 | تحويل عرض سعر إلى فاتورة | Medium | مبيعات |
| 28 | تحويل طلب شراء إلى فاتورة شراء (تحسين) | Medium | مشتريات |
| 29 | إشعار العميل عند جاهزية الطلبية | Medium | طلبيات |
| 30 | استيراد طلبيات من ملف | Medium | مشتريات |
| 31 | PDF احترافي للفواتير | Medium | مشتريات |
| 32 | دعم طابعة حرارية ESC/POS | Medium | مبيعات |
| 33 | استيراد كشف حساب بنكي | Medium | محاسبة |
| 34 | تحليل ميزانية مقارن | Medium | محاسبة |
| 35 | توحيد نظام الأدوار | Medium | صلاحيات |
| 36 | إصلاح ثغرة BCrypt في user_roles_page | Critical | أمان |
| 37 | Lazy Loading حقيقي | Medium | أداء |
| 38 | memory/CPU monitoring | Low | أداء |
| 39 | إخفاء التكلفة في واجهة البيع | Medium | مبيعات |
| 40 | البحث الذكي في POS (تفعيل) | Medium | مبيعات |
| 41 | Quick Customer في فاتورة البيع | Medium | مبيعات |
| 42 | إضافة مورد بالكامل من شاشة الشراء | Medium | مشتريات |
| 43 | سبب إرجاع المشتريات | Low | مشتريات |
| 44 | شاشة المدير التحكمي (Admin Dashboard) تحسين | Medium | Dashboard |
| 45 | ZATCA TLV كامل | Medium | مبيعات |
| 46 | صلاحيات Advanced مربوطة بالواجهة | Medium | صلاحيات |
| 47 | مزامنة حساب بنكي تلقائية محسنة | Low | محاسبة |
| 48 | مقارنة كشف حساب بنكي | Low | محاسبة |
| 49 | تحليل ميزانية بالمقارنة الفعلية/المخططة | Low | محاسبة |
| 50 | تقارير إنتاج/استهلاك المواد | Low | إنتاج |

---

# TOP 50 CRITICAL BUGS

| # | المشكلة | الملف | السطر | الأولوية |
|---|---------|-------|-------|---------|
| 1 | تعديل المنتج لا يحفظ (`_saveProduct` لا يحتوي else branch) | `add_edit_product_dialog.dart` | 119 | Critical |
| 2 | `user_roles_page.dart` يحفظ كلمة المرور plain text بدون BCrypt | `user_roles_page.dart` | 288 | Critical |
| 3 | `hideSalePrices` config غير مربوط بالواجهة | `app_config_service.dart` + `pos_product_card.dart` | 19 | High |
| 4 | POS search معطّل (سطر معلّق) | `product_search_widget.dart` | 32 | High |
| 5 | `customer_statement_page` print button فارغ | `customer_statement_page.dart` | 32-38 | High |
| 6 | `Excel Import` يقبل `.xlsx` لكن لا يقرأها | `data_import_service.dart` | 173 | High |
| 7 | `ExportFormat.excel` يُصدّر CSV فقط | `export_service.dart` | 50-51 | High |
| 8 | `QuickCustomerService` لا يعمل في `sales_invoice_page` | `sales_invoice_page.dart` | 335 | Medium |
| 9 | `ChartService` غير مسجل في DI | `injection_container.dart` | - | Medium |
| 10 | `PaginatedListMixin` dead code | `pagination_mixin.dart` | 7 | Medium |
| 11 | 3 تطبيقات مختلفة للـ stock transfer | `products_dao`, `inventory_service`, `stock_transfer_service` | - | Medium |
| 12 | `StockMovements` و `InventoryTransactions` متقاطعان | `app_database.dart` | 241, 719 | Medium |
| 13 | تضارب تعريفات الأدوار (4 أماكن مختلفة) | `user_role.dart`, `staff_management_page`, `user_roles_page`, `permissions_management_page` | - | High |
| 14 | Hard delete للمستخدمين (لا يمكن التراجع) | `users_dao.dart` | 14 | Medium |
| 15 | `financial_reports_service.dart` غير موجود (مرجع في `injection_container.dart`) | `injection_container.dart` | - | Low |
| 16 | `N+1 query` في `getTopProducts()` | `dashboard_service.dart` | 179-180 | Medium |
| 17 | `FutureBuilder` anti-pattern في تقارير متعددة | `sales_reports_page.dart`, etc. | 84, 188 | Medium |
| 18 | `AdvancedPermissionService` permission codes غير مربوطة بالواجهة | `advanced_permission_service.dart` | 6-39 | Medium |
| 19 | `UserRole` enum لا يحتوي Accountant/User/Viewer | `user_role.dart` | 1-21 | Medium |
| 20 | `access_guard.dart` route-based فقط (لا per-screen) | `access_guard.dart` | 4-56 | Medium |
| 21 | `purchase_details_page.dart` print من القائمة placeholder فقط | `purchases_page.dart` | 272-278 | Medium |
| 22 | `SupplierStatementPage` لا يوجد زر طباعة | `supplier_statement_page.dart` | - | High |
| 23 | `barcode_scanner_service.dart` `scanFromCamera()` و `scanFromFile()` يُعيدان null | `barcode_scanner_service.dart` | 49-55 | Medium |
| 24 | Posting Profiles لا يحتوي OUTPUT_VAT/INPUT_VAT في الواجهة | `posting_profiles_settings_page.dart` | 19-29 | Low |
| 25 | `dashboard_provider.dart` يجلب كل البيانات عند التهيئة | `dashboard_provider.dart` | 34 | Medium |
| 26 | لا يوجد crash reporting | المشروع بالكامل | - | High |
| 27 | لا يوجد caching layer | المشروع بالكامل | - | High |
| 28 | `WarehouseManagerPage` read-only (لا يمكن تعيين مدير) | `warehouse_manager_page.dart` | 37 | Low |
| 29 | `ItemVariants` table stub (فارغة) | `app_database.dart` | 343-346 | Low |
| 30 | لا يوجد batch import للطلبيات | لا يوجد | - | Medium |
| 31 | لا يوجد طباعة ملصقات باركود | لا يوجد | - | High |
| 32 | لا يوجد تصفير جماعي للمخزون | لا يوجد | - | Medium |
| 33 | لا يوجد أرصدة افتتاحية جماعية | لا يوجد | - | High |
| 34 | لا يوجد صندوق بطاقة منفصل | لا يوجد | - | Medium |
| 35 | التحويل متعدد العملات غير مُنفّذ | `transfer_service.dart` | - | High |
| 36 | لا يوجد per-report permissions | `permission_service.dart` | 11 | Medium |
| 37 | لا يوجد per-screen permissions | `access_guard.dart` | - | Medium |
| 38 | لا يوجد home screen customization | `home_page.dart` | - | Low |
| 39 | لا يوجد memory/CPU monitoring | المشروع بالكامل | - | Low |
| 40 | لا يوجد crash reporting (Sentry/Crashlytics) | المشروع بالكامل | - | High |
| 41 | `SalesOrders` lifecycle UI غير موجود | لا يوجد | - | High |
| 42 | لا يوجد تحويل quotation → invoice | لا يوجد | - | Medium |
| 43 | لا يوجد batch allocation UI | لا يوجد | - | Low |
| 44 | لا يوجد purchase approval workflow | لا يوجد | - | Low |
| 45 | لا يوجد budget checking في المشتريات | لا يوجد | - | Low |
| 46 | لا يوجد document attachments UI (attachmentPath field موجود) | لا يوجد | - | Low |
| 47 | لا يوجد expense reason codes | لا يوجد | - | Low |
| 48 | لا يوجد bank statement import UI | لا يوجد | - | Medium |
| 49 | لا يوجد auto bank reconciliation matching | `bank_reconciliation_service.dart` | 49 | Low |
| 50 | لا يوجد consolidated financial reports (multi-branch) | لا يوجد | - | Low |

---

# TOP 50 ARCHITECTURE PROBLEMS

| # | المشكلة | التفاصيل | الأولوية |
|---|---------|---------|---------|
| 1 | **3 تطبيقات مختلفة لـ stock transfer** | `ProductsDao.transferStock()`, `InventoryService.transferStock()`, `StockTransferService.processTransfer()` | High |
| 2 | **نظامان لتتبع المخزون** | `StockMovements` و `InventoryTransactions` مع وظائف متداخلة | High |
| 3 | **4 تعريفات مختلفة للأدوار** | `UserRole` enum, Staff Management, User Roles Page, Permissions Management, Settings Permissions | High |
| 4 | **3 صفحات صلاحيات مكررة** | `auth/permissions_management_page.dart`, `admin/user_roles_page.dart`, `settings/permissions_management_page.dart` | High |
| 5 | **`TransactionEngine` و `PostingEngine` و `FinancialControlService`** تتداخل في وظائف GL posting | 3 خدمات تتعامل مع القيود المحاسبية | Medium |
| 6 | **`AccountingService` (1237 سطر)** يجمع التقارير + logika الأعمال | يجب فصله | Medium |
| 7 | **لا يوجد Repository pattern متسق** | بعض الميزات تستخدم Repository وبعضها DAO مباشرة | Medium |
| 8 | **`sync_log_mixin.dart` + `SyncQueue` table** - نظام المزامنة غير مكتمل | لا يوجد sync فعلي للسيرفر | Medium |
| 9 | **`app_database.dart` يحتوي 87 جدول في ملف واحد** | يجب تقسيمه | Medium |
| 10 | **Dead code**: `financial_reports_service.dart`, `PaginatedListMixin`, `ChartService` (غير مسجل) | كود غير مستخدم | Medium |
| 11 | **`FutureBuilder` في widget tree** بدلاً من pre-fetching | مشكلة أداء في تقارير كثيرة | Medium |
| 12 | **لا يوجد Global State Management متسق** | بعض الميزات Provider وبعضها BLoC وبعضها Stream مباشرة | Medium |
| 13 | **`sales_service.dart` deprecated** لكن لا يزال موجوداً | يجب حذفه | Low |
| 14 | **Duplicate code**: Quick customer creation في أماكن متعددة | `quick_customer_service.dart`, `customers_dao.dart:createQuickCustomer` | Medium |
| 15 | **لا يوجد Error Handling موحد** | كل خدمة تعالج الأخطاء بطريقة مختلفة | Medium |
| 16 | **`injection_container.dart` (465 سطر)** - DI manual without code generation | يمكن استخدام `get_it` + `injectable` | Low |
| 17 | **لا يوجد domain layer متسق** | بعض Entities في `domain/entities` وبعضها في `data/models` | Medium |
| 18 | **`PostingEngine` يحتوي hardcoded account codes** مع fallback | يجب الاعتماد على Posting Profiles بالكامل | Medium |
| 19 | **لا يوجد unit tests كافية** | ملف `item_repository_impl_test.dart` فقط | High |
| 20 | **`app_database.g.dart` ملف ضخم** (generated) | لا يوجد مشكلة لكن يجب عدم تعديله يدوياً | Low |
| 21 | **لا يوجد API layer** | النظام offline-only بدون sync للسيرفر | Medium |
| 22 | **`l10n` Arabic/English** لكن لا يوجد coverage كامل | بعض النصوص hardcoded بالعربية | Medium |
| 23 | **لا يوجد Theming متسق** | `app_theme.dart` موجود لكن بعض الصفحات تتجاوزه | Low |
| 24 | **`native_sql_override.dart` + `dummy_ffi.dart`** - كود مؤقت | يجب حذفه بعد التحقق | Low |
| 25 | **`check_dir.dart`, `decode_and_write.dart`, `test_*.dart`** في root | ملفات اختبار يجب نقلها | Low |
| 26 | **لا يوجد CI/CD pipeline** | لا يوجد `.github/workflows` | Medium |
| 27 | **لا يوجد code generation** (build_runner) محدث | `app_database.g.dart` قد يكون قديماً | Medium |
| 28 | **`analysis_options.yaml`** قد لا يكون مُحسّن | لا يوجد strict analysis | Low |
| 29 | **لا يوجد API documentation** | `API_DOCS.md` موجود لكن قد يكون غير محدث | Low |
| 30 | **`ARCHITECTURE.md` و `blueprint.md`** قد لا يعكسان الحالة الحقيقية | مستندات قد تكون قديمة | Low |
| 31 | **لا يوجد logging framework موحد** | `logger.dart` موجود لكن لا يُستخدم بشكل متسق | Medium |
| 32 | **`event_bus_service.dart`** - EventBus لا يُستخدم في كل الأماكن | بعض الأحداث تُطلق وبعضها لا | Medium |
| 33 | **لا يوجد input validation موحد** | كل صفحة تتحقق بطريقة مختلفة | Medium |
| 34 | **`AppConfigService` يخزن كل الإعدادات كـ key-value** | لا يوجد schema validation | Low |
| 35 | **لا يوجد database migration strategy واضحة** | Schema version 42 لكن لا يوجد migration files منفصلة | Medium |
| 36 | **`DecimalConverter`** - تحويل decimal عبر text في SQLite | بطء محتمل مع كميات كبيرة | Low |
| 37 | **لا يوجد offline-first strategy واضحة** | `SyncQueue` موجود لكن لا يعمل | Medium |
| 38 | **`Branches` table** - لا يوجد multi-branch logic فعلي | الجدول موجود لكن لا يُستخدم | Low |
| 39 | **لا يوجد tenant isolation** | النظام single-tenant فقط | Low |
| 40 | **`Checks` table** - إدارة الشيكات موجودة لكن UI محدود** | `checks_page.dart` موجود لكن قد لا يكون كاملاً | Medium |
| 41 | **لا يوجد auto-save** | لا يوجد حفظ تلقائي للمسودات | Low |
| 42 | **لا يوجد undo/redo** | لا يمكن التراجع عن العمليات | Low |
| 43 | **`Promotions` table** - التخفيضات موجودة لكن لا تُطبق تلقائياً في POS | UI موجود لكن قد لا يعمل بالكامل | Medium |
| 44 | **`PriceLists` و `PriceListItems`** - قوائم الأسعار موجودة لكن Usage محدود | الجداول موجودة | Medium |
| 45 | **`Loyalty` page** موجود لكن قد لا يكون مكتملاً | `loyalty_page.dart` | Medium |
| 46 | **`Approvals` page** موجود لكن قد لا يكون مربوطاً | `approvals_page.dart` | Medium |
| 47 | **`Manufacturing` module** - BOM + Production Orders موجودة لكن قد لا تكون مكتملة | `bom_management_page.dart`, `production_orders_page.dart` | Medium |
| 48 | **`HR module`** - موظفين + مسير رواتب موجودان لكن قد لا يكونا مكتملين | `hr_service.dart`, `payroll_service.dart` | Medium |
| 49 | **`EcommerceIntegrationService`** - خدمة موجودة لكن لا نعرف مدى اكتمالها | `ecommerce_integration_service.dart` | Low |
| 50 | **`ReconciliationService` + `BankReconciliationService`** - تكرار وظيفي | خدمتان تفعلان شيئاً متشابهاً | Medium |

---

# TOP 50 DATABASE PROBLEMS

| # | المشكلة | الجدول | التفاصيل | الأولوية |
|---|---------|-------|---------|---------|
| 1 | **`ItemVariants` table stub** | `ItemVariants` | الجدول فارغ (id, created_at, updated_at فقط) - variants تُخزن في `Products.parent_product_id` | Low |
| 2 | **لا يوجد `MaintenanceTickets` table** | - | النظام بالكامل غير موجود | Critical |
| 3 | **`decimalPlaces` per currency فقط** | `Currencies` | لا يوجد global decimal setting | Medium |
| 4 | **`SyncQueue` table موجودة لكن لا تعمل** | `SyncQueue` | لا يوجد sync للسيرفر | Medium |
| 5 | **`Branches` table موجودة لكن لا تُستخدم** | `Branches` | لا يوجد multi-branch logic | Low |
| 6 | **`ItemVariants` مكررة مع `Products.parent_product_id`** | `ItemVariants`, `Products` | نظامان لنفس الوظيفة | Medium |
| 7 | **`StockMovements` + `InventoryTransactions` متقاطعان** | كلاهما | نظامان يتتبعان نفس الشيء بطريقة مختلفة | High |
| 8 | **`PostingProfiles` لا يحتوي VAT account types في UI** | `PostingProfiles` | OUTPUT_VAT/INPUT_VAT غير متاحة في الإعدادات | Medium |
| 9 | **`AppConfigTable` و `AppSettings` مكرران** | كلاهما | جدولان لنفس الوظيفة | Medium |
| 10 | **`AuditLogs` و `AuditLogsTable` و `AccAuditLogs`** - 3 جداول للمراجعة | 3 جداول | تداخل وظيفي | Medium |
| 11 | **`AccountTransactions` و `GLLines`** متقاطعان | كلاهما | كلاهما يسجل حركات الحسابات | Medium |
| 12 | **`Employees` و `HREmployees`** - جدولان للموظفين | كلاهما | نظامان مختلفان | Medium |
| 13 | **`PayrollEntries`/`PayrollLines` و `HRPayrollRuns`/`HRPayrollDetails`** - نظامان للرواتب | كلاهما | تداخل وظيفي | Medium |
| 14 | **Schema version 42** لكن لا يوجد migration files منفصلة | `app_database.dart` | يجب تنظيم الـ migrations | Medium |
| 15 | **لا يوجد foreign key constraints** بين بعض الجداول | متعددة | بعض العلاقات غير م enforce | Medium |
| 16 | **`Sales.saleType`** - نص افتراضي 'retail' بدون enum** | `Sales` | يجب استخدام enum | Low |
| 17 | **`Customers.customer_type`** - نص افتراضي 'RETAIL'** | `Customers` | يجب استخدام enum | Low |
| 18 | **`Suppliers.supplier_type`** - نص افتراضي 'LOCAL'** | `Suppliers` | يجب استخدام enum | Low |
| 19 | **`Warehouses.account_id` nullable** | `Warehouses` | ربط GL اختياري (قد يكون مطلوباً) | Low |
| 20 | **`Products` لا يحتوي `imageUrl`** | `Products` | لا توجد صور للمنتجات | High |
| 21 | **`Products` لا يحتوي `description`** | `Products` | لا يوجد وصف للمنتجات | Medium |
| 22 | **`SaleItems` لا يحتوي `discount`** | `SaleItems` | لا يوجد خصم على صنف البيع | Medium |
| 23 | **`PurchaseItems` يحتوي `is_carton` boolean** بدلاً من unit reference** | `PurchaseItems` | يجب الربط بـ ProductUnits | Low |
| 24 | **`Shifts` لا يحتوي `branchId`** | `Shifts` | لا يوجد ربط بالفرع | Low |
| 25 | **`CashboxTransactions` لا يحتوي `accountId`** | `CashboxTransactions` | لا يوجد ربط بحساب GL محدد | Medium |
| 26 | **`FinancialTransfers` لا يحتوي `exchangeRate`** | `FinancialTransfers` | لا يوجد دعم عملات متعددة | High |
| 27 | **`Checks` لا يحتوي `bank_account_id`** | `Checks` | لا يوجد ربط بحساب بنكي محدد | Medium |
| 28 | **`Promotions` لا يحتوي `min_quantity`** | `Promotions` | فقط `min_purchase_amount` | Low |
| 29 | **`PriceHistory` لا يحتوي `userId`** | `PriceHistory` | لا يوجد تتبع مَن غيّر السعر | Low |
| 30 | **`ProductBatches` لا يحتوي `supplierId`** | `ProductBatches` | لا يوجد ربط بالمورد | Low |
| 31 | **`SalesOrders` لا يحتوي `warehouseId`** | `SalesOrders` | لا يوجد مخزن محدد للطلبية | Medium |
| 32 | **`PurchaseOrders` لا يحتوي `currencyId`** | `PurchaseOrders` | لا يوجد دعم عملات | Low |
| 33 | **`DeliveryNotes` لا يحتوي `carrierId`** | `DeliveryNotes` | لا يوجد ناقل | Low |
| 34 | **`GoodReceivedNotes` لا يحتوي `inspectionNotes`** | `GoodReceivedNotes` | لا يوجد تفاصيل الفحص | Low |
| 35 | **`InventoryAudits` لا يحتوي `warehouseId`** | `InventoryAudits` | الجرد غير مرتبط بمخزن محدد | Medium |
| 36 | **`InventoryAuditItems` لا يحتوي `unitCost`** | `InventoryAuditItems` | لا يوجد تكلفة للتسويات | Low |
| 37 | **`Reconciliations` لا يحتوي `reconciledBy`** | `Reconciliations` | لا يوجد تبع مَن تم التسوية | Low |
| 38 | **`AccountingPeriods` لا يحتوي `preparedBy`** | `AccountingPeriods` | فقط `closedBy` | Low |
| 39 | **`GLAccounts` balance مُخزّن (denormalized)** | `GLAccounts` | يحدث عبر trigger/query لكن قد يختلف | Medium |
| 40 | **`Customers.discount_rate`** - لا يوجد تطبيق في pricing** | `Customers` | الخصم غير مطبق تلقائياً | Medium |
| 41 | **`Products.allow_free_qty`** - غير مُستخدم في UI** | `Products` | لا يوجد تطبيق | Low |
| 42 | **`Products.is_service`** - غير مُستخدم في UI** | `Products` | لا يوجد تمييز بين منتج وخدمة | Low |
| 43 | **`Products.max_stock`** - غير مُستخدم** | `Products` | لا يوجد تنبيه مخزون أقصى | Low |
| 44 | **`GlobalUnits.is_custom`** - غير مُستخدم** | `GlobalUnits` | لا يوجد تمييز | Low |
| 45 | **`UnitConversions.is_base_unit`** - مكرر مع `ProductUnits.is_default`** | `UnitConversions`, `ProductUnits` | نظامان لنفس الشيء | Medium |
| 46 | **`GLLines.memo` nullable** | `GLLines` | الملاحظات اختيارية | Low |
| 47 | **`SyncableTable` mixin** - `sync_status` integer فقط (1=synced)** | كل الجداول | لا يوجد sync فعلي | Medium |
| 48 | **`AppConfigTable.updated_at`** - لا يوجد `updatedBy`** | `AppConfigTable` | لا يوجد تبع مَن غيّر الإعداد | Low |
| 49 | **`PostingProfiles` لا يحتوي `createdAt`** | `PostingProfiles` | فقط `created_at` via DEFAULT | Low |
| 50 | **`ExchangeRates`** - لا يوجد `isBase` flag** | `ExchangeRates` | يجب تحديد العملة الأساسية | Low |

---

# TOP 50 PERFORMANCE PROBLEMS

| # | المشكلة | الملف | التفاصيل | الأولوية |
|---|---------|-------|---------|---------|
| 1 | **لا يوجد Caching Layer** | المشروع بالكامل | كل طلب يقرأ من SQLite مباشرة | High |
| 2 | **N+1 Query في `getTopProducts()`** | `dashboard_service.dart:179-180` | loop query لكل فاتورة | High |
| 3 | **`FutureBuilder` في widget tree** | `sales_reports_page.dart:84,188` + صفحات أخرى | DB queries مباشرة في الـ build method | High |
| 4 | **`DashboardProvider` يجلب كل البيانات عند Init** | `dashboard_provider.dart:34` | تهيئة بطيئة | High |
| 5 | **`app_database.g.dart` ملف ضخم** | `app_database.g.dart` | generated file قد يكون بطيئاً | Medium |
| 6 | **لا يوجد Indexed Queries كافية** | `app_database.dart` | بعض الاستعلامات لا تستخدم indexes | Medium |
| 7 | **`searchProducts` LIKE query** | `products_dao.dart:182-187` | `LIKE '%query%'` لا يستخدم index | Medium |
| 8 | **`smartSearchCustomers` LIKE query** | `customers_dao.dart:271` | LIKE query مع normalization | Medium |
| 9 | **`getSupplierStatement` JOINs كثيرة** | `suppliers_dao.dart:145-235` | عدة joins في استعلام واحد | Medium |
| 10 | **`getCustomerStatement` JOINs كثيرة** | `customers_dao.dart:177-263` | عدة joins في استعلام واحد | Medium |
| 11 | **`watchAllSales` stream** | `sales_dao.dart:26` | يُعيد كل المبيعات بدون pagination | Medium |
| 12 | **`watchAllPurchases` stream** | `purchases_dao.dart:27` | يُعيد كل المشتريات بدون pagination | Medium |
| 13 | **`getTrialBalance` aggregate query** | `accounting_dao.dart:322-343` | SUM group by على كل GL Lines | Medium |
| 14 | **`getIncomeStatement` aggregate query** | `accounting_dao.dart:547-581` | عدة group by queries | Medium |
| 15 | **`getBalanceSheet` aggregate query** | `accounting_dao.dart:584-613` | عدة group by queries | Medium |
| 16 | **`performInventoryAudit` batch-level settlement** | `inventory_service.dart:164-281` | معالجة كل صنف على حدة | Medium |
| 17 | **`_loadLastPurchasePricesForSupplier`** | `purchase_provider.dart:322-357` | يجلب آخر سعر لكل المنتجات | Medium |
| 18 | **`loadProductInfo`** | `purchase_provider.dart:362-421` | عدة queries لكل منتج | Medium |
| 19 | **`checkAlerts`** | `purchase_provider.dart:482` | يتحقق من كل المنتجات | Medium |
| 20 | **`watchInventoryTransactions`** | `inventory_service.dart` | stream بدون pagination | Medium |
| 21 | **`watchProductBatches`** | `inventory_service.dart` | stream بدون pagination | Medium |
| 22 | **`watchLowStockProducts`** | `inventory_service.dart` | stream بدون pagination | Medium |
| 23 | **`watchExpiringSoonBatches`** | `inventory_service.dart` | stream بدون pagination | Medium |
| 24 | **`getAllAccounts`** | `accounting_dao.dart:129` | يجلب كل الحسابات | Medium |
| 25 | **`watchAccounts`** | `accounting_dao.dart:133` | stream لكل الحسابات | Medium |
| 26 | **`getInvoicesByDateRange` (sales)** | `sales_dao.dart` | range query بدون index مُحسّن | Low |
| 27 | **`getInvoicesByDateRange` (purchases)** | `purchases_dao.dart:204` | range query بدون index مُحسّن | Low |
| 28 | **`getMostSoldProducts`** | `sales_dao.dart:170` | aggregate query مع group by | Low |
| 29 | **`getTopSellingProducts`** | `sales_dao.dart:188` | aggregate query مع joins | Low |
| 30 | **`getProductProfitability`** | `sales_dao.dart:208` | aggregate query مع joins | Low |
| 31 | **`getProductMovementReport`** | `stock_movement_dao.dart` | range query مع joins | Low |
| 32 | **`getExpensesByCostCenter`** | `accounting_dao.dart:616-647` | aggregate query | Low |
| 33 | **`getVatReport`** | `accounting_service.dart:696-779` | عدة queries | Low |
| 34 | **`getCashFlowStatement`** | `accounting_service.dart:1141` | عدة queries | Low |
| 35 | **`getFinancialRatios`** | `accounting_service.dart:402-442` | عدة queries | Low |
| 36 | **`getBalanceSheet`** | `accounting_service.dart:938` | aggregate queries | Low |
| 37 | **`getIncomeStatement`** | `accounting_service.dart:875` | aggregate queries | Low |
| 38 | **`closeFinancialYear`** | `accounting_service.dart:1068` | عدة transactions | Low |
| 39 | **`runAutomaticDepreciation`** | `accounting_service.dart:607` | loop على كل الأصول | Low |
| 40 | **`generateOpeningBalances`** | `accounting_service.dart:781` | loop على كل الحسابات | Low |
| 41 | **`calculateAverageCost`** | `purchase_provider.dart:424` | loop على كل PurchaseItems | Low |
| 42 | **`_getPriceHistory`** | `purchase_provider.dart:444` | query مع limit 10 | Low |
| 43 | **`getSupplierPerformanceReport`** | `supplier_analytics_service.dart:22-49` | عدة queries | Low |
| 44 | **`getDashboardStats`** | `dashboard_service.dart` | عدة queries متزامنة | Low |
| 45 | **`getTopProducts`** | `dashboard_service.dart` | N+1 query (مُذكور أعلاه) | High |
| 46 | **`getExpiringProducts`** | `dashboard_service.dart` | query مع range | Low |
| 47 | **`getRecentSales`** | `dashboard_service.dart` | query مع limit | Low |
| 48 | **`getCashboxBalance`** | `cashbox_dao.dart:27` | aggregate query | Low |
| 49 | **`getAllAccountBalancesAsOfDate`** | `accounting_dao.dart:425-494` | loop على كل الحسابات | Low |
| 50 | **`getAccountBalanceInRange`** | `accounting_dao.dart:358-422` | aggregate query مع range | Low |

---

# TOP 50 UI/UX PROBLEMS

| # | المشكلة | الملف | التفاصيل | الأولوية |
|---|---------|-------|---------|---------|
| 1 | **لا توجد صور منتجات** | `pos_product_card.dart:30-37` | يستخدم `Icons.inventory_2` فقط | High |
| 2 | **`customer_statement` print button فارغ** | `customer_statement_page.dart:32-38` | الزر موجود لكن لا يفعل شيئاً | High |
| 3 | **لا توجد طباعة كشف حساب المورد** | `supplier_statement_page.dart` | لا يوجد زر طباعة | High |
| 4 | **طباعة فواتير المشتريات PDF نصي** | `purchase_details_page.dart:253-304` | لا تصميم احترافي | High |
| 5 | **POS search معطّل** | `product_search_widget.dart:32` | سطر معلّق comment | High |
| 6 | **`hideSalePrices` غير مطبق** | `pos_product_card.dart` | Config موجود لكن UI لا يقرأه | Medium |
| 7 | **لا يوجد تخصيص واجهة الرئيسية** | `home_page.dart` | Layout ثابت بدون إعادة ترتيب | Medium |
| 8 | **`access_denied_page` بسيط جداً** | `access_denied_page.dart:31` | صفحة خطأ básica | Low |
| 9 | **لا يوجد loading state موحد** | المشروع بالكامل | كل صفحة تدير التحميل بطريقة مختلفة | Medium |
| 10 | **لا يوجد error state موحد** | المشروع بالكامل | كل صفحة تدير الأخطاء بطريقة مختلفة | Medium |
| 11 | **لا يوجد empty state موحد** | المشروع بالكامل | بعض الصفحات لا تُظهر رسالة عند عدم وجود بيانات | Medium |
| 12 | **`main_drawer.dart` menu items قد لا تكون كاملة** | `main_drawer.dart:317` | بعض الميزات غير ظاهرة في القائمة | Medium |
| 13 | **لا يوجد RTL support مُحسّن** | المشروع بالكامل | قد يكون هناك مشاكل في عرض النصوص | Medium |
| 14 | **لا يوجد dark mode** | `app_theme.dart` | لا يوجد دعم الوضع الداكن | Low |
| 15 | **لا يوجد responsive design** | المشروع بالكامل | قد لا يعمل بشكل جيد على شاشات مختلفة | Medium |
| 16 | **لا يوجد onboarding** | المشروع بالكامل | لا يوجد شرح للمستخدم الجديد | Low |
| 17 | **`login_page.dart`** - لا يوجد "نسيت كلمة المرور" | `login_page.dart` | لا يوجد استعادة كلمة المرور | Medium |
| 18 | **لا يوجد multi-language UI switch** | `locale_provider.dart` | قد يكون موجود لكن غير ظاهر | Low |
| 19 | **`command_palette.dart`** - قد لا يعرفه المستخدم | `command_palette.dart` | Ctrl+K غير معروف | Low |
| 20 | **لا يوجد skeleton loading** | `skeleton_loader.dart` موجود لكن قد لا يُستخدم | Widget موجود لكن Usage محدود | Low |
| 21 | **`notification_tray.dart`** - قد لا يكون مكتملاً | `notification_tray.dart` | درج الإشعارات | Medium |
| 22 | **لا يوجد confirm dialog موحد** | المشروع بالكامل | كل صفحة تدير التأكيد بطريقة مختلفة | Medium |
| 23 | **`money_form_field.dart`** - قد لا يدعم كل العملات | `money_form_field.dart` | حقل مالي مشترك | Low |
| 24 | **لا يوجد swipe actions** | المشروع بالكامل | لا يوجد swipe to delete/edit | Low |
| 25 | **لا يوجد pull-to-refresh** | المشروع بالكامل | لا يوجد تحديث بالسحب | Medium |
| 26 | **لا يوجد keyboard shortcuts** | المشروع بالكامل | فقط Ctrl+K للبحث | Low |
| 27 | **`breadcrumbs.dart`** - قد لا يعمل بشكل جيد** | `breadcrumbs.dart` | تنقل متدرج | Low |
| 28 | **لا يوجد copy to clipboard** | المشروع بالكامل | لا يوجد نسخ الأرقام | Low |
| 29 | **`period_filter_widget.dart`** - قد لا يكون في كل التقارير** | `period_filter_widget.dart` | فلتر زمني مشترك | Medium |
| 30 | **`print_preview_dialog.dart`** - قد لا يكون مكتملاً** | `print_preview_dialog.dart` | معاينة الطباعة | Medium |
| 31 | **`entity_picker.dart`** - قد لا يكون مُحسّناً للبحث** | `entity_picker.dart` | حقل اختيار الكيانات | Low |
| 32 | **`app_snack_bar.dart`** - لا يوجد snackbar موحد** | `app_snack_bar.dart` | إشعارات مؤقتة | Low |
| 33 | **`permission_guard.dart`** - fallback قد لا يكون مناسباً** | `permission_guard.dart` | حماية الصلاحيات | Low |
| 34 | **`skeleton_loader.dart`** - قد لا يُستخدم** | `skeleton_loader.dart` | تحميل هيكلية | Low |
| 35 | **`sync_status_card.dart`** - قد لا يكون ظاهراً** | `sync_status_card.dart` | حالة المزامنة | Low |
| 36 | **`settings_section.dart`** - قد لا يكون مُستخدم** | `settings_section.dart` | قسم الإعدادات | Low |
| 37 | **`home_card.dart`** - قد لا يكون قابل للتخصيص** | `home_card.dart` | بطاقة الرئيسية | Low |
| 38 | **`admin_dashboard_page.dart`** - KPIs قد لا تكون قابلة للتخصيص** | `admin_dashboard_page.dart` | Dashboard المدير | Medium |
| 39 | **`dynamic_dashboard.dart`** - 2x2 grid فقط** | `dynamic_dashboard.dart` | Dashboard ديناميكي | Low |
| 40 | **`reports_hub_page.dart`** - قد لا يكون مُنظماً جيداً** | `reports_hub_page.dart` | مركز التقارير | Medium |
| 41 | **`category_selector.dart`** - قد لا يكون في كل الشاشات** | `category_selector.dart` | اختيار التصنيف | Low |
| 42 | **`product_grid.dart`** - قد لا يكون responsive** | `product_grid.dart` | شبكة المنتجات | Low |
| 43 | **`cart_widget.dart`** - قد لا يكون مُحسّناً للشاشات الصغيرة** | `cart_widget.dart:483` | سلة المشتريات | Medium |
| 44 | **`checkout_dialog.dart`** - قد لا يدعم كل أنواع الدفع** | `checkout_dialog.dart` | حوار الدفع | Medium |
| 45 | **`sale_details_bottom_sheet.dart`** - قد لا يكون كاملاً** | `sale_details_bottom_sheet.dart` | تفاصيل البيع | Low |
| 46 | **`add_unit_dialog.dart`** - قد لا يكون في كل الأماكن** | `add_unit_dialog.dart` | إضافة وحدة | Low |
| 47 | **`barcode_scanner_dialog.dart`** - `scanFromCamera()` يُعيد null** | `barcode_scanner_dialog.dart` | مسح الباركود | High |
| 48 | **`widget/entity_picker.dart`** - لا يوجد lazy search** | `entity_picker.dart` | يجلب كل الكيانات | Medium |
| 49 | **`account_selector_widget.dart`** - قد لا يكون مُحسّناً** | `account_selector_widget.dart` | اختيار الحساب | Low |
| 50 | **`command_palette.dart`** - نتائج البحث قد لا تكون مُرتبة** | `command_palette.dart` | بحث عام | Low |

---

# ROADMAP: COMPLETE ERP SYSTEM

## Phase 1: Critical Fixes (1-2 weeks)

| # | المهمة | الأولوية | أيام العمل |
|---|--------|---------|-----------|
| 1 | إصلاح BUG تعديل المنتج (`add_edit_product_dialog.dart:119`) | Critical | 0.5 |
| 2 | إصلاح ثغرة BCrypt في `user_roles_page.dart:288` | Critical | 0.5 |
| 3 | تفعيل طباعة كشف حساب العميل (`customer_statement_page.dart:32`) | Critical | 1 |
| 4 | إضافة طباعة كشف حساب المورد | Critical | 1 |
| 5 | تفعيل POS search (`product_search_widget.dart:32`) | Critical | 0.5 |
| 6 | ربط `hideSalePrices` بالواجهة | Critical | 1 |
| 7 | ربط `QuickCustomerService` بـ `sales_invoice_page.dart` | Critical | 1 |
| 8 | إضافة صور المنتجات (DB + UI) | Critical | 2 |
| 9 | إصلاح `ExportFormat.excel` ليدعم XLSX حقيقي | Critical | 2 |
| 10 | إصلاح `Excel Import` ليدعم XLSX | Critical | 2 |
| **المجموع** | | | **12 يوم** |

## Phase 2: Core Missing Features (3-4 weeks)

| # | المهمة | الأولوية | أيام العمل |
|---|--------|---------|-----------|
| 11 | بناء وحدة الصيانة بالكامل (جداول + DAO + Service + UI) | High | 10 |
| 12 | بناء صفحة طلبيات العملاء (UI) | High | 3 |
| 13 | بناء صفحة عروض الأسعار (UI) + تحويل لفاتورة | High | 3 |
| 14 | بناء توليد وطباعة الباركود | High | 3 |
| 15 | بناء تقرير المشتريات المستقل | High | 2 |
| 16 | بناء تقرير العملاء | High | 2 |
| 17 | بناء تقرير الصناديق | High | 2 |
| 18 | إضافة طباعة PDF احترافية لفواتير المشتريات | High | 2 |
| 19 | إضافة صندوق البطاقة المنفصل | High | 2 |
| 20 | بناء صفحة أرصدة افتتاحية جماعية | High | 2 |
| **المجموع** | | | **31 يوم** |

## Phase 3: Medium Priority Features (4-6 weeks)

| # | المهمة | الأولوية | أيام العمل |
|---|--------|---------|-----------|
| 21 | بناء Crash Reporting (Sentry/Crashlytics) | Medium | 2 |
| 22 | بناء Caching Layer | Medium | 3 |
| 23 | توحيد نظام الأدroles (4 أماكن → Enum واحد) | Medium | 2 |
| 24 | إصلاح 3 صفحات الصلاحيات المكررة | Medium | 2 |
| 25 | بناء per-screen permissions | Medium | 3 |
| 26 | بناء per-report permissions | Medium | 2 |
| 27 | الشراء بطاقة/تحويل بنكي | Medium | 1 |
| 28 | بناء بحث ذكي للمنتجات والموردين | Medium | 2 |
| 29 | بناء تقرير توريد وصرف | Medium | 2 |
| 30 | بناء تقرير إيرادات مستقل | Medium | 1 |
| 31 | بناء تصفير المخزون | Medium | 1 |
| 32 | بناء نقل تصنيف جماعي | Medium | 1 |
| 33 | التحويل متعدد العملات | Medium | 3 |
| 34 | تحويل عرض سعر/طلبية إلى فاتورة | Medium | 2 |
| 35 | إشعار العميل عند جاهزية الطلبية | Medium | 1 |
| 36 | استيراد طلبيات من ملف | Medium | 2 |
| 37 | طباعة حرارية ESC/POS | Medium | 3 |
| 38 | إخفاء التكلفة في واجهة البيع | Medium | 1 |
| 39 | Lazy Loading حقيقي | Medium | 2 |
| 40 | توحيد Error/Loading/Empty states | Medium | 3 |
| **المجموع** | | | **41 يوم** |

## Phase 4: Low Priority & Optimization (2-3 weeks)

| # | المهمة | الأولوية | أيام العمل |
|---|--------|---------|-----------|
| 41 | ترتيب وإخفاء عناصر الواجهة الرئيسية | Low | 2 |
| 42 | Dark mode support | Low | 2 |
| 43 | Responsive design improvements | Low | 3 |
| 44 | Onboarding screens | Low | 2 |
| 45 | Pull-to-refresh | Low | 1 |
| 46 | Keyboard shortcuts | Low | 1 |
| 47 | Memory/CPU monitoring | Low | 2 |
| 48 | Database cleanup (dead tables, consolidation) | Low | 3 |
| 49 | Unit tests coverage | Low | 5 |
| 50 | Documentation update | Low | 2 |
| **المجموع** | | | **23 يوم** |

## Phase 5: Advanced Features (4-6 weeks)

| # | المهمة | الأولوية | أيام العمل |
|---|--------|---------|-----------|
| 51 | ZATCA TLV full compliance | Medium | 5 |
| 52 | Bank statement import + auto-reconciliation | Medium | 5 |
| 53 | Multi-branch consolidation | Low | 10 |
| 54 | Offline-first sync to server | Medium | 10 |
| 55 | API layer for web/mobile | Medium | 10 |
| **المجموع** | | | **40 يوم** |

## الإجمالي

| المرحلة | الأيام |
|---------|--------|
| Phase 1: Critical Fixes | 12 يوم |
| Phase 2: Core Missing Features | 31 يوم |
| Phase 3: Medium Priority | 41 يوم |
| Phase 4: Low Priority | 23 يوم |
| Phase 5: Advanced Features | 40 يوم |
| **المجموع الكلي** | **147 يوم عمل (~5 أشهر)** |

---

*تم إنشاء هذا التقرير بتاريخ 2026-06-19通过 تحليل شامل لـ 370 ملف Dart و 87 جدول قاعدة بيانات و 72+ خدمة و 62+ مسار.*
