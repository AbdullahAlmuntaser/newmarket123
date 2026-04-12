# 🌟 ERP System Blueprint & Implementation Details

**الهدف العام:** تحويل النظام المحاسبي الحالي إلى نظام ERP متكامل (Enterprise Resource Planning) باستخدام Flutter لواجهة المستخدم وSQLite (Drift) كقاعدة بيانات محلية، مع التركيز على إدارة العمليات التجارية الرئيسية وتقديم تحليل مالي ومحاسبي دقيق.

---

## 🏗️ الهيكل العام والتكنولوجيا المستخدمة:

*   **الواجهة الأمامية (Frontend):** Flutter (Dart) لتطوير تطبيقات متعددة المنصات (Android, Web, iOS).
    *   **إدارة الحالة (State Management):** يعتمد على مزيج من `Provider` و `ChangeNotifierProvider` لإدارة حالة التطبيق عبر الواجهات المختلفة، بالإضافة إلى `BLoC` في بعض الأماكن (مثال: `CategoryBloc`).
    *   **التنقل (Routing):** `go_router` لإدارة المسارات والانتقال بين الصفحات بشكل فعال ومرن.
    *   **التصميم (UI/UX):** يعتمد على Material Design 3، مع دعم السمات الفاتحة والداكنة (Light/Dark Themes) وخطوط مخصصة (Google Fonts).
    *   **التعريب (Localization):** دعم لغات متعددة (العربية والإنجليزية) باستخدام `flutter_localizations`.
*   **قاعدة البيانات (Local Database):** SQLite باستخدام مكتبة `Drift` (المعروفة سابقاً بـ `Moor`) لتجريد التعامل مع SQL، مما يوفر طبقة آمنة وموثوقة للبيانات المحلية.
    *   **الترحيل (Migrations):** استراتيجية ترحيل قوية (onUpgrade) للتعامل مع تحديثات بنية قاعدة البيانات، مما يضمن التوافق مع الإصدارات السابقة والحفاظ على البيانات.
    *   **DAOs (Data Access Objects):** فئات مخصصة للتعامل مع البيانات الخاصة بكل نطاق (مثل `SalesDao`, `ProductsDao`, `AccountingDao`).
*   **الخدمات الأساسية (Core Services):**
    *   **Event Bus Architecture:** نظام ناقل أحداث (مثال: `EventBusService`) لفصل الاهتمامات وتنسيق العمليات بين المكونات المختلفة.
    *   **Sync Service:** خدمة لمزامنة البيانات (وإن كانت غير مفعلة بالكامل كآلية مزامنة خارجية بعد).
    *   **AI Service:** (موجودة في الهيكل) يمكن استخدامها مستقبلاً لدمج وظائف الذكاء الاصطناعي.
*   **هيكل المشروع:** منظم حسب النطاقات (domain-driven)، مع فصل واضح بين طبقات Presentation, Domain, Data.

---

## ⚙️ الوحدات والوظائف المنفذة (مع تفاصيل الواجهات وآليات العمل):

### 1. 👥 إدارة العملاء (Customers Management)
*   **الجدول:** `Customers` (ID, Name, Phone, TaxNumber, Address, Email, CustomerType, IsActive, CreditLimit, Balance, AccountId, CurrencyId, ExchangeRate).
*   **الواجهة:** `CustomersPage` (عرض قائمة العملاء، إضافة/تعديل عميل).
*   **آلية العمل:**
    *   يدعم أنواع العملاء (Retail, Wholesale, VIP).
    *   يرتبط بحساب في دفتر الأستاذ العام (GLAccount).
    *   **كشف حساب العميل (`CustomerStatementPage`):** يعرض سجل مفصل لمعاملات العميل (مبيعات، مدفوعات، مرتجعات) مع رصيد مستحق.

### 2. 🤝 إدارة الموردين (Suppliers Management)
*   **الجدول:** `Suppliers` (ID, Name, Phone, ContactPerson, TaxNumber, Address, Email, SupplierType, IsActive, Balance, AccountId).
*   **الواجهة:** `SuppliersPage` (عرض قائمة الموردين، إضافة/تعديل مورد).
*   **آلية العمل:**
    *   يدعم أنواع الموردين (Local, International).
    *   يرتبط بحساب في دفتر الأستاذ العام (GLAccount).
    *   **كشف حساب المورد (`SupplierStatementPage`):** يعرض سجل مفصل لمعاملات المورد (مشتريات، مدفوعات، مرتجعات) مع رصيد مستحق.

### 3. 📦 إدارة المنتجات والمخزون (Products & Inventory Management)
*   **الجدول:** `Products` (ID, Name, SKU, CategoryId, Unit, CartonUnit, PiecesPerCarton, BuyPrice, SellPrice, WholesalePrice, Stock, AlertLimit, ExpiryDate, TaxRate).
*   **الجداول المرتبطة:** `Categories`, `Warehouses`, `ProductBatches`, `UnitConversions`, `StockTakes`, `StockTakeItems`, `BillOfMaterials`.
*   **الواجهات:**
    *   `ProductsPage`: إدارة المنتجات، إضافة/تعديل تفاصيل المنتج.
    *   `CategoriesPage`: إدارة فئات المنتجات.
    *   `LowStockProductsPage`: عرض المنتجات ذات المخزون المنخفض.
    *   `UnitConversionPage`: إدارة وحدات التحويل للمنتج الواحد (حبة، كرتون).
    *   `WarehouseManagementPage`: إدارة المستودعات.
    *   `StockTakePage`: صفحة الجرد المخزني.
*   **آلية العمل:**
    *   دعم الوحدات المتعددة للمنتج (مثال: حبة، كرتون) مع معامل تحويل.
    *   يدعم المخازن المتعددة.
    *   **سجل حركات المخزون:** يتم تتبع الكميات في `ProductBatches` (الدفعة) و`Products` (إجمالي المخزون).
    *   **منطق خصم المخزون:** يتم استخدام **FEFO (First Expired, First Out)** لخصم الكميات من الدفعات بناءً على تاريخ انتهاء الصلاحية الأقدم أولاً، ثم تاريخ الإنشاء الأقدم.
    *   **الجرد المخزني:** يتم تسجيل الكميات المتوقعة والفعلية والفروقات، مع دعم توليد قيود محاسبية لتسوية العجز أو الزيادة (يتطلب تطوير المنطق المحاسبي لذلك).
    *   **قائمة المواد (BOM):** يدعم تجميع المنتجات من مواد خام.

### 4. 🛒 إدارة المبيعات (Sales Management)
*   **الجدول:** `Sales` (ID, CustomerId, Total, Discount, Tax, PaymentMethod, IsCredit, Status, CurrencyId, ExchangeRate, **QRCode, Hash, Signature**).
*   **الجداول المرتبطة:** `SaleItems`, `SalesReturns`, `SalesReturnItems`.
*   **الواجهات:**
    *   `PosPage`: نقطة البيع (Point of Sale) لعمليات البيع السريعة.
    *   `SalesHistoryPage`: عرض سجل المبيعات.
    *   `AddSalesReturnPage`: صفحة لإنشاء مرتجع مبيعات.
*   **آلية العمل:**
    *   دعم البيع النقدي والآجل.
    *   حالات الفواتير (Draft, Posted, Cancelled).
    *   **خصم المخزون:** يتم خصم كميات المنتجات المباعة من المخزون باستخدام منطق FEFO.
    *   **الربط المحاسبي:** توليد قيود محاسبية تلقائية عند إنشاء البيع (من خلال `EventBus`).
    *   **الفوترة الإلكترونية (ZATCA Phase 2):**
        *   تتضمن حقولاً لتخزين `QRCode`, `Hash`, `Signature` للفاتورة.
        *   دالة `generateZatcaQRCode` في `ErpLogic` لتوليد كود QR بتنسيق TLV مشفر بـ Base64، متوافق مع متطلبات المرحلة الثانية لهيئة الزكاة والضريبة والجمارك (يشمل اسم البائع، الرقم الضريبي، التاريخ والوقت، إجمالي الفاتورة، إجمالي الضريبة).

### 5. 💰 إدارة المشتريات (Purchase Management)
*   **الجدول:** `Purchases` (ID, SupplierId, Total, Tax, **LandedCosts**, InvoiceNumber, Date, IsCredit, Status, WarehouseId, CurrencyId, ExchangeRate).
*   **الجداول المرتبطة:** `PurchaseItems`, `PurchaseReturns`, `PurchaseReturnItems`.
*   **الواجهات:**
    *   `PurchasesPage`: عرض سجل المشتريات.
    *   `AddPurchasePage`: إضافة فاتورة مشتريات جديدة.
    *   `PurchaseDetailsPage`: عرض تفاصيل فاتورة مشتريات.
    *   `AddPurchaseReturnPage`: صفحة لإنشاء مرتجع مشتريات.
*   **آلية العمل:**
    *   ربط بالموردين.
    *   دعم حالات الفاتورة (Draft, Ordered, Received, Cancelled).
    *   **إضافة المخزون:** تضاف الكميات للمخزون فور تأكيد استلامها، مع تحديث `buyPrice` للمنتج.
    *   **التكاليف المضافة (Landed Costs):** يتم توزيع مبلغ `landedCosts` (تكاليف الشحن، الجمارك، إلخ) على أصناف فاتورة المشتريات بنسبة قيمة كل صنف، مما يؤدي إلى تحديث `costPrice` لكل دفعة و `buyPrice` للمنتج بشكل دقيق.
    *   **الربط المحاسبي:** توليد قيود محاسبية تلقائية عند إنشاء الشراء (من خلال `EventBus`).

### 6. 📊 المحاسبة المالية (Financial Accounting)
*   **الجدول الأساسي:** `GLAccounts` (ID, Code, Name, Type (Asset, Liability, Equity, Revenue, Expense), ParentId, IsHeader, Balance).
*   **الجداول المرتبطة:** `GLEntries`, `GLLines`, `AccountingPeriods`, `FixedAssets`, `Reconciliations`, `CashboxTransactions`, **`CostCenters`**.
*   **الواجهات:**
    *   `ChartOfAccountsPage`: شجرة الحسابات (دليل الحسابات).
    *   `GeneralLedgerPage`: دفتر الأستاذ العام.
    *   `BalanceSheetPage`: الميزانية العمومية.
    *   `IncomeStatementPage`: قائمة الدخل.
    *   `TrialBalancePage`: ميزان المراجعة.
    *   `CashFlowPage`: قائمة التدفقات النقدية (UI موجودة، المنطق المحاسبي يحتاج لتطوير).
    *   `ManualJournalEntryPage`: صفحة للقيود اليومية اليدوية.
    *   `FixedAssetsPage`: إدارة الأصول الثابتة.
    *   `ReconciliationPage`: صفحة التسويات.
    *   `ShiftsPage`: إدارة ورديات العمل (للكاشير، مرتبطة بالمقبوضات النقدية).
    *   `ChecksPage`: إدارة الشيكات (المقبوضة والمدفوعة).
*   **آلية العمل:**
    *   نظام محاسبي مزدوج القيد.
    *   **مراكز التكلفة (Cost Centers):** تم إضافة جدول `CostCenters`، ويمكن ربط كل قيد محاسبي (`GLLine`) بمركز تكلفة محدد، مما يتيح تتبع الأداء المالي حسب الأقسام أو المشاريع.
    *   **إدارة الشيكات:** تتبع حالات الشيكات (Pending, Collected, Bounced) وربطها بحسابات دفتر الأستاذ.
    *   دعم تحديد رصيد الحساب حتى تاريخ معين أو خلال فترة.

### 7. 📈 التقارير والرقابة (Reporting & Audit)
*   **الجدول:** `AuditLogs` (UserId, Action, TargetEntity, EntityId, Details, Timestamp).
*   **الواجهات:**
    *   `SalesReportsPage`: تقارير المبيعات.
    *   `InventoryReportsScreen`: تقارير المخزون.
    *   `VatReportPage`: تقرير ضريبة القيمة المضافة.
    *   `AuditLogPage`: سجل التدقيق (لمتابعة نشاطات المستخدمين).
    *   `InventoryAuditPage`: تقرير جرد المخزون.
*   **آلية العمل:**
    *   تسجيل تفصيلي لجميع العمليات الهامة (إنشاء، تعديل، حذف) مع هوية المستخدم والوقت.
    *   توفر مجموعة من التقارير الأساسية.

### 8. 🛡️ إدارة المستخدمين والصلاحيات (User & Permissions Management)
*   **الجدول:** `Users`, `Permissions`, `RolePermissions`.
*   **الواجهة:** `StaffManagementPage` (إدارة المستخدمين والأدوار).
*   **آلية العمل:**
    *   نظام RBAC (Role-Based Access Control) للأدوار (مدير، محاسب، كاشير).
    *   كل دور يمتلك مجموعة من الصلاحيات.

### 9. ⚙️ الإعدادات والمزامنة (Settings & Sync)
*   **الواجهات:** `BackupPage`, `SyncPage`, `PrinterSettingsPage`, `CurrencyRatesPage`.
*   **آلية العمل:**
    *   `CurrencyRatesPage`: إدارة أسعار صرف العملات.
    *   إعدادات الطباعة.
    *   صفحة للمزامنة (تتطلب تكامل مع خدمة سحابية).

### 10. 🌍 دعم العملات المتعددة (Multi-Currency Support)
*   **الجدول:** `Currencies` (Code, Name, ExchangeRate, IsBase).
*   **الربط:** تم تضمين `CurrencyId` و `ExchangeRate` في جداول `Sales`, `Purchases`, `GLEntries`, `GLLines`, `Customers`, `Suppliers`, `Checks`.
*   **آلية العمل:** يسمح بتحديد العملة الأساسية وإدخال أسعار الصرف، ويمكن إجراء المعاملات بعملات مختلفة مع تسجيل سعر الصرف المستخدم.

---

## 🚀 ملخص الميزات المتقدمة المنفذة:

*   **نظام محاسبي متكامل:** مع دعم دليل الحسابات، قيود اليومية، دفتر الأستاذ العام، الميزانية، قائمة الدخل، وميزان المراجعة.
*   **إدارة مخزون مرنة:** تدعم وحدات قياس متعددة، مستودعات متعددة، وتتبع المخزون بالدفعات (Batches) ومنطق FEFO.
*   **تتبع دقيق للتكلفة:**
    *   **التكاليف المضافة (Landed Costs):** يتم توزيعها تلقائياً على تكلفة شراء المنتجات.
    *   **مراكز التكلفة (Cost Centers):** تتيح ربط القيود المحاسبية بمراكز تكلفة لتتبع الأداء بشكل مفصل.
*   **الامتثال للفوترة الإلكترونية:** دعم متطلبات ZATCA Phase 2 (حقول Hash, Signature, وZATCA QR Code).
*   **إدارة مالية متقدمة:** دعم للشيكات (المقبوضة والمدفوعة) وإدارة التسويات.
*   **نظام صلاحيات قوي:** يضمن التحكم في وصول المستخدمين ووظائفهم.

---

## 🎯 المهام المتبقية والأولويات القصوى (للتطوير المستقبلي):

1.  **منطق توليد قيود المحاسبة تلقائياً:** على الرغم من وجود `EventBus`، يتطلب الأمر تطوير منطق محدد لتوليد القيود المحاسبية لكل عملية تجارية (بيع، شراء، دفع، مرتجع) بشكل كامل.
2.  **واجهات المستخدم لمراكز التكلفة:** تم إنشاء الجداول والمنطق الخلفي، لكن تحتاج لواجهة مستخدم لإنشاء وإدارة مراكز التكلفة، وواجهة لربطها بالقيود المحاسبية.
3.  **تقرير قائمة التدفقات النقدية (`CashFlowPage`):** الواجهة موجودة، ولكن يحتاج المنطق المحاسبي خلفها للتطوير الكامل.
4.  **نظام تسعير ذكي:**
    *   واجهة المستخدم لإدارة عروض ترويجية وخصومات حجم التداول.
    *   تطبيق منطق التسعير المخصص وقوائم الأسعار.
5.  **تكامل المزامنة السحابية:** تطوير خدمة المزامنة مع حل سحابي (مثل Firebase/Firestore) لتخزين البيانات.
6.  **تقارير الربحية المتقدمة:** تطوير تقارير الربحية حسب المنتج/العميل/القسم بشكل كامل.
7.  **الإهلاك التلقائي للأصول الثابتة:** تطوير المنطق والواجهة لإهلاك الأصول الثابتة.

💡 **الهدف النهائي:** بعد إكمال هذه المراحل، سيصبح النظام ERP عالمي المواصفات، قادراً على إدارة عمليات الشركات الكبيرة والمتوسطة بدقة متناهية.
