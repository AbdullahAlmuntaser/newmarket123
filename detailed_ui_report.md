# تقرير مراجعة نظام ERP المحاسبي (SystemMarket) - تفصيل واجهات المستخدم
## تقرير مراجع الكود الاحترافي -DETAILED UI ANALYSIS
**تاريخ التقرير:** 2026-04-22  
**نظام المراجعة:** Flutter/Dart ERP System  
**المشروع:** /home/user/systemmarket

---

# 1) شاشة POS (نقاط البيع)

## 1.1 الحقول (Fields)

| الحقل | النوع | القيمة الافتراضية |_DB |_validators | الملاحظات |
|-------|------|-----------------|-----|-----------|----------|
| رقم الفاتورة | TextField (readonly) | INV-YYYYMMDD-XXXX | ✓ DB | لا يوجد | يُولَّد تلقائيًا |
| التاريخ | DatePicker | DateTime.now() | ✓ DB | لا يوجد | يمكن تغييره |
| نوع الدفع | DropdownButtonFormField | cash | ✓ DB | لا يوجد | خيارات: cash, credit |
| barcode/SKU | TextField | - | ✓ DB | لا يوجد | مسح الباركود |
| اسم العميل (سريع) | TextField | - | ✓ DB | لا يوجد | إنشاء عميل FAST |
| اختيار العميل | DropdownButtonFormField | - | ✓ DB | لا يوجد | من قائمة العملاء |
| المنتج | DropdownButtonFormField | - | ✓ DB | لا يوجد | من قائمة المنتجات |
| الوحدة | DropdownButtonFormField | pcs | ✓ DB | لا يوجد | حبة، كرتون، كيس |
| الكمية | TextField | - | ✓ DB | رقم موجب | يُدخل المستخدم |
| السعر | TextField | سعر البيع | ✓ DB | رقم | يُحسب تلقائيًا |
| الخصم | TextField | 0 | ✓ DB | رقم | يُدخل المستخدم |
| الإجمالي | readonly | محسوب | UI فقط | لا يوجد | مجموع + خصم |

## 1.2 الأزرار (Buttons)

| الزر | الوظيفة | الملف والدالة | الحالة |
|-----|--------|--------------|-------|
| إضافة صنف (+) | [`_addNewItem()`](lib/presentation/features/pos/pos_page.dart:478) | ✓ يعمل |
| حذف صنف (trash icon) | [`setState(() => _items.removeAt(index))`](lib/presentation/features/pos/pos_page.dart:454) | ✓ يعمل |
| إتمام البيع (F10) | [`_completeSale()`](lib/presentation/features/pos/pos_page.dart:644) → [`transactionEngine.postSale()`](lib/core/services/transaction_engine.dart:144) | ✓ يعمل + تكامل |
| طباعة | [`_printSale()`](lib/presentation/features/pos/pos_page.dart:737) | ⚠️ placeholder فقط |
| إغلاق الوردية | [`_showCloseShiftDialog()`](lib/presentation/features/pos/pos_page.dart:99) | ⚠️ غير مُنفَّذ |
| فتح باركود | showDatePicker في dialog | ✓ يعمل |

## 1.3 عناصر إضافية (Additional Elements)

| العنصر | النوع | الوظيفة |
|-------|------|--------|
| Checkbox 'طباعة تلقائية' | Checkbox | لتفعيل الطباعة التلقائية |
| تنبيهات | Alert Panel | عرض تحذيرات المخزون وسقف الائتمان |
| ListView للأصناف | List | عرض الأصناف المختارة |
| GridView | Grid | عرض المنتجات الأكثر مبيعًا |

## 1.4 حالة التكامل

| الخدمة | الملف | الدالة | الحالة |
|--------|-------|--------|-------|
| إنشاء فاتورة | [`sales_dao.createSale()`](lib/data/datasources/local/daos/sales_dao.dart:80) | ✓ |
| ترحيل الفاتورة | [`TransactionEngine.postSale()`](lib/core/services/transaction_engine.dart:144) | ✓ |
| التحقق من المخزون | [`transaction_engine.dart:173`](lib/core/services/transaction_engine.dart:173) | ✓ |
| تحديث رصيد العميل | [`transaction_engine.dart:240`](lib/core/services/transaction_engine.dart:240) | ��� |
| إرسال حدث | [`SaleCreatedEvent`](lib/core/events/app_events.dart:5) | ✓ |

---

# 2) شاشة فاتورة المبيعات ([`sales_invoice_page.dart`](lib/presentation/features/sales/sales_invoice_page.dart))

## 2.1 الحقول (Fields)

| الحقل | النوع |_DB |_validators |
|-------|------|----------|----------|
| barcode | TextField | ✓ DB | - |
| اختيار المنتج | DropdownButtonFormField | ✓ DB | - |
| اختيار العميل | DropdownButtonFormField | ✓ DB | - |
| تاريخ الفاتورة | DatePicker | ✓ DB | - |
| الملاحظات | TextField | ✓ DB | - |
| الوحدة | DropdownButtonFormField | ✓ DB | - |
| الكمية | TextField | ✓ DB | رقم موجب |
| السعر | TextField | ✓ DB | رقم |
| الخصم | TextField | ✓ DB | رقم |

## 2.2 الأزرار (Buttons)

| الزر | الوظيفة | الملف والدالة |
|-----|--------|----------------|
| إضافة صنف | [`setState(() => _items.add())] | ✓ |
| حفظ كمسودة | [`_saveInvoice(db, post: false)`](lib/presentation/features/sales/sales_invoice_page.dart:400) | ✓ |
| ترحيل | [`_saveInvoice(db, post: true)`](lib/presentation/features/sales/sales_invoice_page.dart:411) → [`transactionEngine.postSale()`](lib/core/services/transaction_engine.dart:144) | ✓ |
| مرتجع | [`_showReturnDialog()`](lib/presentation/features/sales/sales_invoice_page.dart:398) | ✓ |

## 2.3 حالة التكامل

✓ متصلة بـ TransactionEngine
✓ تُنشئ Sales و SaleItems في قاعدة البيانات
✓ تُرسل الفاتورة عبر postSale()

---

# 3) شاشة المشتريات ([`add_purchase_page.dart`](lib/presentation/features/purchases/add_purchase_page.dart))

## 3.1 الحقول (Fields)

| الحقل | النوع |_DB |_validators |
|-------|------|----------|----------|
| رقم Invoice الخارجي | TextField | ✓ DB | - |
| تاريخ الفاتورة | DatePicker | ✓ DB | - |
| اختيار المورد | DropdownButtonFormField | ✓ DB | - |
| اختيار المستودع | DropdownButtonFormField | ✓ DB | - |
| نوع الدفع | DropdownButtonFormField | ✓ DB | - |
| barcode | TextField | ✓ DB | - |
| اختيار المنتج | DropdownButtonFormField | ✓ DB | - |
| الوحدة (كرتون/قطعة) | DropdownButtonFormField | ✓ DB | - |
| الكمية | TextField | ✓ DB | رقم موجب |
| السعر | TextField | ✓ DB | رقم |
| الخصم | TextField | ✓ DB | رقم |
| تكاليف الشحن | TextField | ✓ DB | رقم |
| ضرائب مخصصة | TextField | ✓ DB | رقم |

## 3.2 الأزرار (Buttons)

| الزر | الوظيفة | الملف والدالة |
|-----|--------|----------------|
| تحميل PO | [`_showLoadPODialog()`](lib/presentation/features/purchases/add_purchase_page.dart:252) | ✓ |
| إضافة صنف | [`_addNewItem()`](lib/presentation/features/purchases/add_purchase_page.dart:396) | ✓ |
| حفظ كمسودة | [`_savePurchase(db, post: false)`](lib/presentation/features/purchases/add_purchase_page.dart:565) | ✓ |
| ترحيل | [`_savePurchase(db, post: true)`](lib/presentation/features/purchases/add_purchase_page.dart:576) → [`transactionEngine.postPurchase()`](lib/core/services/transaction_engine.dart:30) | ✓ |

## 3.3 حالة التكامل

✓ متصلة بـ TransactionEngine
✓ تُنشئ Purchases و PurchaseItems
✓ تُنشئ Batches (دفعات)
✓ تُحدِّث المخزون
✓ تُحسب Landed Costs

---

# 4) شاشة العملاء ([`customers_page.dart`](lib/presentation/features/customers/customers_page.dart))

## 4.1 الحقول (Fields)

| الحقل | النوع |_DB |_validators |
|-------|------|----------|----------|
| البحث | TextField | ✓ DB (onChanged) | - |
| اسم العميل | TextField | ✓ DB | مطلوب |
| رقم الهاتف | TextField | ✓ DB | - |
| الرقم الضريبي | TextField | ✓ DB | - |
| البريد الإلكتروني | TextField | ✓ DB | - |
| العنوان | TextField | ✓ DB | - |
| سقف الائتمان | TextField | ✓ DB | رقم |
| العملة | DropdownButtonFormField | ✓ DB | - |
| معدل الصرف | TextField | ✓ DB | رقم |
| نوع العميل | DropdownButtonFormField | ✓ DB | RETAIL/WHOLESALE/VIP |

## 4.2 الأزرار (Buttons)

| الزر | الوظيفة | الملف والدالة |
|-----|--------|----------------|
| إضافة عميل | [`add_edit_customer_dialog.dart`](lib/presentation/features/customers/widgets/add_edit_customer_dialog.dart) | ✓ |
| دفع/سداد | showDialog [_payAmountController] | ✓ |
| كشف حساب | [`customer_statement_page.dart`](lib/presentation/features/customers/customer_statement_page.dart) | ✓ |
| حذف | icon button | ✓ |

## 4.3 حالة التكامل

✓ متصلة بـ Customers table
✓ متصلة بـ GLAccounts (accountId FK)
✓ يمكن عرض كشف الحساب

---

# 5) شاشة الموردين ([`suppliers_page.dart`](lib/presentation/features/suppliers/suppliers_page.dart))

## 5.1 الحقول (Fields)

| الحقل | النوع |_DB |_validators |
|-------|------|----------|----------|
| البحث | TextField | ✓ DB | - |
| اسم المورد | TextField | ✓ DB | مطلوب |
| رقم الهاتف | TextField | ✓ DB | - |
| person الاتصال | TextField | ✓ DB | - |
| الرقم الضريبي | TextField | ✓ DB | - |
| العنوان | TextField | ✓ DB | - |
| البريد | TextField | ✓ DB | - |
| نوع المورد | DropdownButtonFormField | ✓ DB | LOCAL/INTERNATIONAL |

## 5.2 الأزرار (Buttons)

| الزر | الوظيفة | الملف والدالة |
|-----|--------|----------------|
| إضافة مورد | [`add_edit_supplier_dialog.dart`](lib/presentation/features/suppliers/widgets/add_edit_supplier_dialog.dart) | ✓ |
| دفع/سداد | showDialog | ✓ |
| كشف حساب | [`supplier_statement_page.dart`](lib/presentation/features/suppliers/supplier_statement_page.dart) | ✓ |

---

# 6) شاشة المخزون والمستودعات

## 6.1 إدارة المستودعات ([`warehouse_management_page.dart`](lib/presentation/features/inventory/warehouse_management_page.dart))

| الحقل | النوع |_DB |
|-------|------|-----|
| اسم المستودع | TextField |
| الموقع | TextField |

**الحالة:** ⚠️ UI فقط - أزرار موجودة لكنغير مُفعَّلة بالكامل

## 6.2 نقل المخزون ([`stock_transfer_page.dart`](lib/presentation/features/inventory/stock_transfer_page.dart))

| الحقل | النوع |_DB |
|-------|------|-----|
| من مستودع | DropdownButtonFormField |
| إلى مستودع | DropdownButtonFormField |
| المنتج | DropdownButtonFormField |
| الدفعة | DropdownButtonFormField |
| الكمية | TextField |
| ملاحظات | TextField |

**الأزرار:**
- إضافة نقل: [`stock_transfer_service`](lib/core/services/stock_transfer_service.dart)

**الحالة:** ✓ يعمل

## 6.3 الجرد ([`stock_take_page.dart`](lib/presentation/features/inventory/stock_take_page.dart))

| الحقل | النوع |_DB |
|-------|------|-----|
| المستودع | DropdownButtonFormField |
| المنتج | DropdownButtonFormField |
| الكمية الفعلية | TextField |
| ملاحظات | TextField |

**الأزرار:**
- بدء جرد: [`_finalizeStockTake()`](lib/presentation/features/inventory/stock_take_page.dart:236)
- إضافة أصناف: [`_navigateToAddItem()`](lib/presentation/features/inventory/stock_take_page.dart:148)

**الحالة:** ✓ يعمل

---

# 7) شاشات المحاسبة

## 7.1 شجرة الحسابات ([`chart_of_accounts_page.dart`](lib/presentation/features/accounting/chart_of_accounts_page.dart))

| الحقل | النوع |_DB |
|-------|------|-----|
| رمز الحساب | TextField | ✓ DB |
| اسم الحساب | TextField | ✓ DB |
| نوع الحساب | DropdownButtonFormField | ✓ DB |

**الأزرار:**
- إضافة حساب: [`add account dialog`](lib/presentation/features/accounting/chart_of_accounts_page.dart:154)

## 7.2 دفتر اليومية ([`general_ledger_page.dart`](lib/presentation/features/accounting/general_ledger_page.dart))

**الحالة:** ✓ عرض فقط - عرض القيود

## 7.3 الميزان ([`trial_balance_page.dart`](lib/presentation/features/accounting/trial_balance_page.dart))

**الحالة:** ✓ عرض فقط

## 7.4 القيود اليدوية ([`manual_journal_entry_page.dart`](lib/presentation/features/accounting/manual_journal_entry_page.dart))

| الحقل | النوع |_DB |
|-------|------|-----|
| الوصف | TextField | ✓ DB |
| التاريخ | DatePicker | ✓ DB |
| الحساب | DropdownButtonFormField | ✓ DB |
| مدين | TextField | ✓ DB |
| دائن | TextField | ✓ DB |

**الأزرار:**
- إضافة سطر: [`setState(() => _lines.add())`](lib/presentation/features/accounting/manual_journal_entry_page.dart:90)
- حفظ القيد: [`_saveEntry()`](lib/presentation/features/accounting/manual_journal_entry_page.dart:199) → GLEntries + GLLines

## 7.5 الفترات المحاسبية ([`accounting_periods_page.dart`](lib/presentation/features/accounting/accounting_periods_page.dart))

| الحقل |_Type |_DB |
|-------|------|-----|
| اسم الفترة | TextField | ✓ DB |
| تاريخ البداية | DatePicker | ✓ DB |
| تاريخ النهاية | DatePicker | ✓ DB |

**الأزرار:**
- إنشاء فترة: [`_createPeriod()`](lib/presentation/features/accounting/accounting_periods_page.dart:98)
- إغلاق فترة: [`_closePeriod()`](lib/presentation/features/accounting/accounting_periods_page.dart:154)
- إعادة فتح: [`_reopenPeriod()`](lib/presentation/features/accounting/accounting_periods_page.dart:160)

## 7.6 المصروفات ([`expenses_page.dart`](lib/presentation/features/accounting/expenses_page.dart))

| الحقل |_Type |_DB |
|-------|------|-----|
| الوصف | TextField | ✓ DB |
| المبلغ | TextField | ✓ DB |
| حساب المصروفات | DropdownButtonFormField | ✓ DB |
| حساب الدفع | DropdownButtonFormField | ✓ DB |

---

# 8) ملخص الحالة العامة

## 8.1 ملخص الواجهات

| الشاشة | الحقول | الأزرار |_DB_ | الخدمات | الحالة |
|--------|-------|--------|------|---------|---------|
| POS | 12 | 6 | ✓ | ✓ TransactionEngine | مكتملة |
| فاتورة المبيعات | 10 | 4 | ✓ | ✓ TransactionEngine | مكتملة |
| المشتريات | 14 | 4 | ✓ | ✓ TransactionEngine | مكتملة |
| العملاء | 10 | 3 | ✓ | ✓ | مكتملة |
| الموردين | 8 | 3 | ✓ | ✓ | مكتملة |
| المستودعات | 2 | 2 | UI | ⚠️ جزئية |
| نقل المخزون | 6 | 1 | ✓ | ✓ StockTransfer | مكتملة |
| الجرد | 4 | 2 | ✓ | ✓ InventoryService | مكتملة |
| شجرة الحسابات | 3 | 1 | ✓ | ✓ | مكتملة |
| القيود اليدوية | 5 | 2 | ✓ | ✓ AccountingService | مكتملة |
| الفترات المحاسبية | 3 | 3 | ✓ | ✓ | مكتملة |
| المصروفات | 4 | 1 | ✓ | ✓ AccountingService | مكتملة |

## 8.2 النواقص الرئيسية

1. **المستودعات:** UI فقط وليس هناكfunctions نشطة
2. **طباعة POS:** Function placeholder فقط
3. **إغلاق الوردية:** Function placeholder فقط

---

**نهاية التقرير التفصيلي**