# تحليل واجهات المشتريات والمبيعات

## parte 1: واجهة المشتريات (Purchases)

### الخطوة 1: اختيار المورد والمستودع

**الملف:** [`lib/presentation/features/purchases/add_purchase_page.dart:105`](lib/presentation/features/purchases/add_purchase_page.dart:105)

**الحقول:**
- `_selectedSupplier`: المورد المختار (من جدول Suppliers)
- `_selectedWarehouse`: المستودع المستهدف (من جدول Warehouses)
- `_selectedStatus`: حالة الفاتورة (DRAFT | ORDERED | RECEIVED)

**الكود:**

```dart
StreamBuilder<List<Supplier>>(
  stream: db.select(db.suppliers).watch(),
  ...
  onChanged: (value) => setState(() => _selectedSupplier = value),
)

StreamBuilder<List<Warehouse>>(
  stream: db.select(db.warehouses).watch(),
  ...
  onChanged: (value) => setState(() => _selectedWarehouse = value),
)
```

**الشرح:** يتم عرض قائمة الموردين والمستودعات من قاعدة البيانات.

---

### الخطوة 2: إضافة الأصناف

**الملف:** [`lib/presentation/features/purchases/add_purchase_page.dart:350`](lib/presentation/features/purchases/add_purchase_page.dart:350)

**دالة:** `_showAddProductDialog`

**آلية إضافة المنتج:**

1. عرض dialog يحتوي على قائمة المنتجات
2. اختيار المنتج
3. إدخال الكمية والسعر
4. إضافة للصنفات في قائمة `_items`

---

### الخطوة 3: حساب المجاميع

**الملف:** [`lib/presentation/features/purchases/add_purchase_page.dart:30`](lib/presentation/features/purchases/add_purchase_page.dart:30)

**الكود:**

```dart
double get _subtotal =>
    _items.fold(0, (sum, item) => sum + (item.quantity * item.price));
double get _taxAmount => double.tryParse(_taxController.text) ?? 0.0;
double get _total => _subtotal + _taxAmount;
```

---

### الخطوة 4: حفظ الفاتورة والترحيل

**الملف:** [`lib/presentation/features/purchases/add_purchase_page.dart:359`](lib/presentation/features/purchases/add_purchase_page.dart:359)

**دالة:** `_savePurchase`

**الخطوات:**

1. **إنشاء سجل المشتريات:**
   ```dart
   final purchaseCompanion = PurchasesCompanion.insert(
     id: drift.Value(purchaseId),
     supplierId: drift.Value(_selectedSupplier!.id),
     total: _total,
     tax: drift.Value(_taxAmount),
     invoiceNumber: drift.Value(_invoiceController.text),
     isCredit: drift.Value(_isCreditPurchase),
     status: drift.Value(_selectedStatus),
     warehouseId: drift.Value(_selectedWarehouse?.id),
   );
   ```

2. **إنشاء أصناف الفاتورة:**
   ```dart
   final itemsCompanions = _items.map((item) => 
     PurchaseItemsCompanion.insert(
       purchaseId: purchaseId,
       productId: item.product.id,
       quantity: item.quantity,
       price: item.price,
     )
   ).toList();
   ```

3. **حفظ في قاعدة البيانات:**
   ```dart
   await db.purchasesDao.createPurchase(
     purchaseCompanion: purchaseCompanion,
     itemsCompanions: itemsCompanions,
     userId: authProvider.currentUser?.id,
   );
   ```

4. **الترحيل التلقائي (إذا كانت الحالة RECEIVED):**
   ```dart
   if (_selectedStatus == 'RECEIVED') {
     await sl<TransactionEngine>().postPurchase(
       purchaseId,
       userId: authProvider.currentUser?.id,
     );
   }
   ```

---

### الخطوة 5: ما يحدث عند الترحيل

**الملف:** [`lib/core/services/transaction_engine.dart:30`](lib/core/services/transaction_engine.dart:30)

**دالة:** `postPurchase`

**العمليات:**

1. ✅ **إنشاء Batch جديد للمنتج:**
   ```dart
   final batchId = const Uuid().v4();
   await db.into(db.productBatches).insert(
     ProductBatchesCompanion.insert(
       id: Value(batchId),
       productId: item.productId,
       warehouseId: purchase.warehouseId ?? '',
       batchNumber: 'PUR-${purchase.id.substring(0, 8)}',
       quantity: Value(qtyInBaseUnit),
       costPrice: Value(finalUnitCost),
     ),
   );
   ```

2. ✅ **تحديث المخزون:**
   ```dart
   await (db.update(db.products)..where((p) => p.id.equals(item.productId)))
       .write(ProductsCompanion(
         stock: Value(product.stock + qtyInBaseUnit),
         buyPrice: Value(finalUnitCost),
       ));
   ```

3. ✅ **تسجيل حركة المخزون:**
   ```dart
   await db.into(db.inventoryTransactions).insert(
     InventoryTransactionsCompanion.insert(
       productId: item.productId,
       quantity: qtyInBaseUnit,
       type: 'PURCHASE',
       referenceId: purchaseId,
     ),
   );
   ```

4. ✅ **تحديث رصيد المورد (إذا آجل):**
   ```dart
   if (purchase.isCredit && purchase.supplierId != null) {
     await (db.update(db.suppliers)..where(...))
         .write(SuppliersCompanion(balance: Value(supplier.balance + purchase.total)));
   }
   ```

5. ✅ **إطلاق حدث للمحاسبة:**
   ```dart
   eventBus.fire(PurchasePostedEvent(purchase, items, userId: userId));
   ```

---

### الخطوة 6: القيود المحاسبية

**الملف:** [`lib/core/services/accounting_service.dart:817`](lib/core/services/accounting_service.dart:817)

**دالة:** `postPurchase`

**قيد الشراء:**

| الحساب | مدين | دائن |
|--------|------|------|
| المخزون | ✅ المبلغ | |
| ضريبة القيمة المضافة | ✅ الضريبة | |
| الصندوق/المورد | | ✅ الإجمالي |

```dart
final lines = [
  // مدين: المخزون
  GLLinesCompanion.insert(
    accountId: inventoryAccount.id,
    debit: Value(inventoryValue),
  ),
  // مدين: ضريبة VAT (إن وجدت)
  if (purchase.tax > 0)
    GLLinesCompanion.insert(
      accountId: taxAccount.id,
      debit: Value(purchase.tax),
    ),
  // دائن: الصندوق أو المورد
  GLLinesCompanion.insert(
    accountId: creditAccountId,
    credit: Value(purchase.total),
  ),
];
```

---

## parte 2: واجهة إرجاع المشتريات (Purchase Returns)

### الخطوة 1: اختيار فاتورة المشتريات

**الملف:** [`lib/presentation/features/purchases/add_purchase_return_page.dart`](lib/presentation/features/purchases/add_purchase_return_page.dart)

**الحقول:**
- `_selectedPurchase`: الفاتورة المراد إرجاعها
- `_returnedQuantities`: خريطة للمنتجات والكميةالمرجعة

---

### الخطوة 2: الترحيل

**الكود:**

```dart
await sl<TransactionEngine>().postPurchaseReturn(
  returnId,
  userId: authProvider.currentUser?.id,
);
```

**الملف:** [`lib/core/services/transaction_engine.dart:424`](lib/core/services/transaction_engine.dart:424)

**العمليات:**
1. خصم الكميات من المخزون
2. إنشاء قيد محاسبي معكوس

---

## parte 3: واجهة المبيعات (Sales)

### ملاحظة: المبيعات تمر عبر POS

**الملف:** [`lib/presentation/features/pos/pos_page.dart`](lib/presentation/features/pos/pos_page.dart)

**الخطوات:**

1. ✅ **إضافة منتج للسلة**
2. ✅ **تغيير الوحدة** (حبة ← كرتون)
3. ✅ **تطبيق قائمة الأسعار**
4. ✅ **اختيار طريقة الدفع** (نقدي/آجل)
5. ✅ **إتمام البيع** (CheckoutEvent)

---

### الخطوة 1: إضافة منتج

**الملف:** [`lib/presentation/features/pos/bloc/pos_bloc.dart:234`](lib/presentation/features/pos/bloc/pos_bloc.dart:234)

**دالة:** `_onAddProduct`

**الكود:**

```dart
CartItem(
  product: product,
  unitName: unitName,
  unitFactor: factor,
  unitPrice: priceToUse,
)
```

---

### الخطوة 2: إتمام البيع

**الملف:** [`lib/presentation/features/pos/bloc/pos_bloc.dart:335`](lib/presentation/features/pos/bloc/pos_bloc.dart:335)

**دالة:** `_onCheckout`

**الكود:**

```dart
await db.salesDao.createSale(
  saleCompanion: saleCompanion,
  itemsCompanions: itemsCompanions,
);

// ترحيل تلقائي
await transactionEngine.postSale(saleId, userId: event.userId);
```

---

### الخطوة 3: ما يحدث عند الترحيل

**الملف:** [`lib/core/services/transaction_engine.dart:144`](lib/core/services/transaction_engine.dart:144)

**دالة:** `postSale`

**العمليات:**

1. ✅ **التحقق من المخزون:**
   ```dart
   if (product.stock < remainingToDeduct) {
     throw Exception('المخزون غير كافٍ');
   }
   ```

2. ✅ **خصم المخزون (FEFO):**
   ```dart
   // Get batches ordered by expiry date
   final batches = await (db.select(db.productBatches)
         ..where((b) => b.productId.equals(item.productId))
         ..where((b) => b.quantity.isBiggerThanValue(0))
         ..orderBy([(b) => OrderingTerm(expression: b.expiryDate)])
         .get();
   
   // Deduct from oldest batches
   await (db.update(db.productBatches)..where(...))
       .write(ProductBatchesCompanion(
         quantity: Value(batch.quantity - deductFromThisBatch),
       ));
   ```

3. ✅ **تحديث المخزون الكلي:**
   ```dart
   await (db.update(db.products)..where(...))
       .write(ProductsCompanion(stock: Value(product.stock - totalDeducted)));
   ```

4. ✅ **تسجيل حركة المخزون:**
   ```dart
   await db.into(db.inventoryTransactions).insert(
     InventoryTransactionsCompanion.insert(
       productId: item.productId,
       quantity: -deductFromThisBatch,
       type: 'SALE',
       referenceId: saleId,
     ),
   );
   ```

5. ✅ **تحديث رصيد العميل (إذا آجل):**
   ```dart
   if (sale.isCredit && sale.customerId != null) {
     await (db.update(db.customers)..where(...))
         .write(CustomersCompanion(balance: Value(customer.balance + sale.total)));
   }
   ```

6. ✅ **إطلاق حدث للمحاسبة:**
   ```dart
   eventBus.fire(SaleCreatedEvent(sale, items, userId: userId));
   ```

---

### الخطوة 4: القيود المحاسبية

**الملف:** [`lib/core/services/accounting_service.dart:688`](lib/core/services/accounting_service.dart:688)

**دالة:** `postSale`

**قيد البيع النقدي:**

| الحساب | مدين | دائن |
|--------|------|------|
| الصندوق | ✅ الإجمالي | |
| الإيرادات | | ✅ الصافي |
| ضريبة القيمة المضافة | | ✅ الضريبة |

**قيد البيع الآجل:**

| الحساب | مدين | دائن |
|--------|------|------|
| العملاء | ✅ الإجمالي | |
| الإيرادات | | ✅ الصافي |
| ضريبة القيمة المضافة | | ✅ الضريبة |

---

## parte 4: واجهة إرجاع المبيعات (Sales Returns)

### الخطوة 1: اختيار فاتورة البيع

**الملف:** [`lib/presentation/features/sales/add_sales_return_page.dart:44`](lib/presentation/features/sales/add_sales_return_page.dart:44)

**الحقول:**
- `_selectedSale`: الفاتورة الأصلية
- `_returnedQuantities`: خريطة كميات الإرجاع

---

### الخطوة 2: الترحيل

**الملف:** [`lib/presentation/features/sales/add_sales_return_page.dart:291`](lib/presentation/features/sales/add_sales_return_page.dart:291)

**الكود:**

```dart
await sl<TransactionEngine>().postSaleReturn(
  returnId,
  userId: authProvider.currentUser?.id,
);
```

**الملف:** [`lib/core/services/transaction_engine.dart:261`](lib/core/services/transaction_engine.dart:261)

**العمليات:**
1. إضافة الكميات للمخزون
2. إنشاء قيد معكوس (إيرادات سالبة)
3. تحديث رصيد العميل (إذا كان آجل)