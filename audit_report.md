# 🔍 ERP System Comprehensive Audit Report - Supermarket ERP

## 📊 System Overview
- **Architecture:** Clean Architecture (partially followed), BLoC/Provider for State Management, Drift (SQLite) for Data Persistence.
- **Complexity:** High (Multi-currency, Multi-unit, Multi-warehouse, FEFO Inventory, Double-entry Accounting).
- **Readiness:** **55%** (Not Production Ready).

---

## 🚨 Critical Issues (الأخطر)

### 1. block_accounting_bridge | فجوة الترحيل المحاسبي
*   **المشكلة:** محرك العمليات (`TransactionEngine`) يطلق أحداث `SaleCreatedEvent` و `PurchasePostedEvent` بعد البيع أو الشراء، لكن `AccountingService` لا يستمع لهذه الأحداث ولا يقوم بإنشاء القيود المحاسبية التلقائية.
*   **الأثر:** النظام يسجل حركات مخزنية ولكن لا يسجل قيود يومية (GL Entries) للمبيعات والمشتريات. ميزان المراجعة والتقارير المالية ستكون فارغة أو غير صحيحة تماماً.

### 2. 📉 Stock Doubling Bug | خطأ مضاعفة المخزون
*   **الموقع:** `TransactionEngine.postSaleReturn`
*   **المشكلة:** في حالة إرجاع صنف لم يتم العثور على دفعة (Batch) له، يتم تحديث مخزون المنتج `product.stock` داخل جملة `else` ثم يتم تحديثه **مرة أخرى** خارج الجملة الشرطية.
*   **الأثر:** عند المرتجع، يتم إضافة الكمية مرتين للمخزون، مما يؤدي لبيانات مخزنية وهمية.

### 3. 🧠 Incorrect COGS Calculation | حساب تكلفة مبيعات خاطئ
*   **الموقع:** `AccountingService.postSale`
*   **المشكلة:** يتم حساب تكلفة البضاعة المباعة (COGS) باستخدام `product.buyPrice` (آخر سعر شراء أو سعر ثابت).
*   **الأثر:** هذا يتنافى مع مبدأ FEFO/FIFO المطبق في المخزون. يجب استخدام التكلفة الفعلية المحسوبة من الدفعات (Batches) والممرة عبر الحدث (`event.cogs`).

### 4. 🗄️ Database Desync | عدم تطابق المخزون والدفعات
*   **الموقع:** `InventoryService.performInventoryAudit`
*   **المشكلة:** عند وجود زيادة في الجرد وعدم وجود أي دفعة سابقة للمنتج، النظام لا يقوم بإنشاء دفعة جديدة بل يكتفي بتحديث `product.stock`.
*   **الأثر:** سيصبح إجمالي المخزون في جدول المنتجات لا يساوي مجموع الكميات في جدول الدفعات، مما يسبب أخطاء عند البيع لاحقاً (Insufficient Stock).

---

## ⚠️ Logical Errors (أخطاء منطقية)

*   **FEFO Priority:** ترتيب الدفعات يضع التاريخ `NULL` في المقدمة (بسبب سلوك SQLite). الأصناف التي ليس لها تاريخ انتهاء يجب أن تستهلك أخيراً وليس أولاً.
*   **Concurrency Hazards:** تحديث المخزون يتم بقراءة القيمة ثم طرحها ثم كتابتها `Value(product.stock - qty)`. هذا يسبب فقدان بيانات في حالة حدوث عمليتين متزامنتين. يجب استخدام SQL Expressions مثل `stock = stock - ?`.
*   **Hardcoded Branch:** الكود `BR001` مزروع في أغلب العمليات، مما يجعل النظام غير قابل للتوسع لفروع متعددة برغم وجود جدول `Branches`.

---

## 🧠 Architecture Problems (مشاكل التصميم)

*   **Service Isolation:** الخدمات لا تلتزم بـ Transactional Database الممررة من Drift. كل خدمة تستخدم نسخة `AppDatabase` الخاصة بها، مما قد يؤدي لـ Deadlocks أو قراءة بيانات غير مكتملة داخل الـ Transactions.
*   **Redundant Units:** يوجد تكرار في تعريف الوحدات بين جدول المنتجات (`cartonUnit`, `boxUnit`) وجدول `UnitConversions` و `ProductUnits`. هذا يؤدي لارتباك في واجهة البرمجة وتعارض في البيانات.

---

## 📉 Performance Issues (الأداء)

*   **Event Bus Bottleneck:** الاستماع للأحداث يتم بشكل غير متزامن (async without await) في `AccountingService` مما قد يؤدي لتداخل عمليات الكتابة في قاعدة البيانات.
*   **Running Balances:** حساب الرصيد التراكمي في `AccountTransactions` يتم برمجياً بدلاً من استعلام SQL متقدم، مما يبطئ العمليات مع زيادة حجم البيانات.

---

## 🛠️ Fix Plan (خطة الإصلاح)

1.  **المحاسبة:** ربط أحداث `SaleCreatedEvent` و `PurchasePostedEvent` في `AccountingService` واستخدام `cogs` الممرة من المخزون.
2.  **المخزون:** إصلاح دالة `postSaleReturn` لمنع التحديث المزدوج للمخزون.
3.  **التزامن:** تحويل عمليات تحديث الكميات إلى SQL Expressions (Atomic Updates).
4.  **التصميم:** توحيد منطق الوحدات (Units) وإلغاء الحقول الزائدة في جدول المنتجات.
5.  **المستودعات:** إصلاح منطق تسوية الجرد لضمان إنشاء دفعات للزيادة دائماً.

---

## 🚀 Upgrades (تحسينات احترافية)

*   إضافة دعم الضريبة المضافة (VAT) بشكل أعمق ليشمل الخصومات.
*   تحويل `PostingEngine` ليعمل بناءً على `PostingProfiles` بشكل كامل وقابل للتخصيص من المستخدم.
*   إضافة ميزة "تجميد المخزون" أثناء عمليات الجرد الكبيرة.

---

## 📊 System Score: 55%
> **الخلاصة:** النظام يمتلك واجهة ممتازة وهيكلية جيدة كبداية، لكن "المنطق البرمجي الداخلي" (Backend Logic) يعاني من ثغرات قاتلة ستؤدي لانهيار الحسابات والمخزون في بيئة عمل حقيقية (Production). لا ينصح بالبيع أو الاستخدام الفعلي قبل معالجة النقاط أعلاه.
