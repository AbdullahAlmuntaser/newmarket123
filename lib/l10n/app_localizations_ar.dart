// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'تطبيق المحاسبة';

  @override
  String get home => 'الرئيسية';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get pos => 'نقطة البيع';

  @override
  String get products => 'المنتجات';

  @override
  String get categories => 'الفئات';

  @override
  String get customers => 'العملاء';

  @override
  String get suppliers => 'الموردين';

  @override
  String get purchases => 'المشتريات';

  @override
  String get returns => 'المرتجعات';

  @override
  String get reports => 'التقارير';

  @override
  String get sales => 'سجل المبيعات';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get backupDb => 'نسخ احتياطي';

  @override
  String get welcome => 'مرحباً';

  @override
  String get add => 'إضافة';

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get accountingSystem => 'نظام المحاسبة';

  @override
  String get loginButton => 'دخول';

  @override
  String get loginHint => 'تلميح: admin / 123';

  @override
  String get invalidCredentials => 'بيانات الدخول غير صحيحة';

  @override
  String get quickActions => 'إجراءات سريعة';

  @override
  String get seedProducts => 'إضافة بيانات تجريبية';

  @override
  String get viewSales => 'عرض المبيعات';

  @override
  String get overview => 'نظرة عامة';

  @override
  String get totalSales => 'إجمالي المبيعات';

  @override
  String get todaySales => 'مبيعات اليوم';

  @override
  String get revenue => 'إيراد';

  @override
  String get pendingSync => 'في انتظار المزامنة';

  @override
  String get seedDataAdded => 'تم إضافة البيانات التجريبية!';

  @override
  String get wholesale => 'جملة';

  @override
  String get clearCart => 'مسح السلة';

  @override
  String get cartEmpty => 'السلة فارغة';

  @override
  String get subtotal => 'المجموع الفرعي';

  @override
  String get discount => 'الخصم';

  @override
  String get tax => 'الضريبة (15%)';

  @override
  String get total => 'الإجمالي';

  @override
  String get proceedToCheckout => 'إتمام عملية البيع';

  @override
  String get completePayment => 'إكمال الدفع';

  @override
  String get selectCustomer => 'اختر عميل (اختياري)';

  @override
  String get cashPayment => 'دفع نقدي';

  @override
  String get creditSale => 'بيع آجل';

  @override
  String get selectCustomerError => 'يرجى اختيار عميل للبيع الآجل';

  @override
  String get customerNameHint => 'ابدأ الكتابة للبحث أو إضافة عميل جديد';

  @override
  String get addCustomerForCredit => 'إضافة عميل جديد للبيع الآجل';

  @override
  String get searchProducts => 'البحث عن منتجات...';

  @override
  String get noProductsFound => 'لم يتم العثور على منتجات';

  @override
  String get skuLabel => 'باركود';

  @override
  String get stockLabel => 'المخزون';

  @override
  String get stock => 'المخزون';

  @override
  String get category => 'الفئة';

  @override
  String get price => 'السعر';

  @override
  String get productAdded => 'تم إضافة المنتج بنجاح';

  @override
  String get productUpdated => 'تم تحديث المنتج بنجاح';

  @override
  String get searchCustomers => 'البحث عن عملاء...';

  @override
  String get noCustomersFound => 'لم يتم العثور على عملاء';

  @override
  String get noPhone => 'لا يوجد رقم هاتف';

  @override
  String balanceLabel(Object balance) {
    return 'الرصيد: $balance';
  }

  @override
  String limitLabel(Object limit) {
    return 'الحد: $limit';
  }

  @override
  String get customerAdded => 'تم إضافة العميل بنجاح';

  @override
  String get customerUpdated => 'تم تحديث العميل بنجاح';

  @override
  String get addCustomer => 'إضافة عميل';

  @override
  String get editCustomer => 'تعديل عميل';

  @override
  String get customerName => 'اسم العميل';

  @override
  String get enterNameError => 'يرجى إدخال الاسم';

  @override
  String get phoneLabel => 'الهاتف';

  @override
  String get creditLimitLabel => 'حد الائتمان';

  @override
  String get totalCustomers => 'إجمالي العملاء';

  @override
  String get searchSuppliers => 'البحث عن موردين...';

  @override
  String get noSuppliersFound => 'لم يتم العثور على موردين';

  @override
  String get noContactPerson => 'لا يوجد مسؤول اتصال';

  @override
  String get supplierAdded => 'تم إضافة المورد بنجاح';

  @override
  String get supplierUpdated => 'تم تحديث المورد بنجاح';

  @override
  String get addSupplier => 'إضافة مورد';

  @override
  String get editSupplier => 'تعديل مورد';

  @override
  String get supplierName => 'اسم المورد';

  @override
  String get contactPerson => 'مسؤول الاتصال';

  @override
  String get purchasesHistory => 'سجل المشتريات';

  @override
  String get noPurchases => 'لا يوجد مشتريات مسجلة بعد.';

  @override
  String invoiceLabel(Object invoice) {
    return 'فاتورة: $invoice';
  }

  @override
  String supplierLabel(Object supplier) {
    return 'المورد: $supplier';
  }

  @override
  String dateLabel(Object date) {
    return 'التاريخ: $date';
  }

  @override
  String get unknown => 'غير معروف';

  @override
  String get newPurchase => 'مشتريات جديدة';

  @override
  String get purchaseDetails => 'تفاصيل المشتريات';

  @override
  String get loading => 'جاري التحميل...';

  @override
  String get totalPaid => 'إجمالي المدفوع';

  @override
  String get newPurchaseInvoice => 'فاتورة مشتريات جديدة';

  @override
  String get selectSupplier => 'اختر مورد';

  @override
  String get invoiceNumberLabel => 'رقم الفاتورة';

  @override
  String get noProductsAdded => 'لم يتم إضافة منتجات بعد.';

  @override
  String qtyAtPrice(Object price, Object qty) {
    return 'الكمية: $qty @ $price';
  }

  @override
  String get savePurchase => 'حفظ المشتريات';

  @override
  String get purchaseSaved => 'تم حفظ المشتريات بنجاح!';

  @override
  String get addProductToPurchase => 'إضافة منتج للمشتريات';

  @override
  String get productLabel => 'المنتج';

  @override
  String get quantityLabel => 'الكمية';

  @override
  String get buyPriceLabel => 'سعر الشراء';

  @override
  String get noSalesFound => 'لم يتم العثور على مبيعات';

  @override
  String saleIdLabel(Object id) {
    return 'بيعة رقم $id';
  }

  @override
  String get synced => 'تم المزامنة';

  @override
  String get pending => 'قيد الانتظار';

  @override
  String get saleDetails => 'تفاصيل البيع';

  @override
  String get newSale => 'بيع جديد';

  @override
  String get returnsManagement => 'إدارة المرتجعات';

  @override
  String get salesReturns => 'مرتجع مبيعات';

  @override
  String get purchaseReturns => 'مرتجع مشتريات';

  @override
  String get newReturn => 'مرتجع جديد';

  @override
  String get noReturnsFound => 'لم يتم العثور على مرتجعات.';

  @override
  String returnIdLabel(Object id) {
    return 'رقم المرتجع: $id';
  }

  @override
  String amountReturnedLabel(Object amount) {
    return 'المبلغ: $amount';
  }

  @override
  String get createReturn => 'إنشاء مرتجع';

  @override
  String get fromSale => 'من بيعة';

  @override
  String get fromPurchase => 'من مشتريات';

  @override
  String txLabel(Object id) {
    return 'رقم العملية: $id';
  }

  @override
  String get financialReports => 'التقارير المالية';

  @override
  String get totalProfitLoss => 'إجمالي الأرباح/الخسائر';

  @override
  String get totalSalesRevenue => 'إجمالي المبيعات (الإيرادات)';

  @override
  String get totalPurchasesExpenses => 'إجمالي المشتريات (المصاريف)';

  @override
  String get grossProfit => 'إجمالي الربح';

  @override
  String get outstandingBalances => 'الأرصدة المستحقة';

  @override
  String get customerDebts => 'ديون العملاء';

  @override
  String get supplierDebts => 'ديون الموردين';

  @override
  String get inventoryValue => 'قيمة المخزون';

  @override
  String get totalStockValue => 'إجمالي قيمة المخزون (بسعر الشراء)';

  @override
  String get addProduct => 'إضافة منتج';

  @override
  String get editProduct => 'تعديل منتج';

  @override
  String get productNameLabel => 'اسم المنتج';

  @override
  String get skuBarcodeLabel => 'باركود';

  @override
  String get enterSkuError => 'يرجى إدخال الباركود';

  @override
  String get categoryLabel => 'الفئة';

  @override
  String get sellPriceLabel => 'سعر البيع';

  @override
  String get initialStockLabel => 'المخزون الأولي';

  @override
  String get payAmount => 'دفع مبلغ';

  @override
  String get paymentAmount => 'مبلغ الدفع';

  @override
  String get paymentSuccess => 'تم تسجيل الدفع بنجاح';

  @override
  String get enterAmountError => 'يرجى إدخال مبلغ صحيح';

  @override
  String get scanBarcode => 'مسح الباركود';

  @override
  String get inventoryReports => 'تقارير المخزون';

  @override
  String get lowStockProducts => 'منتجات منخفضة المخزون';

  @override
  String get noLowStockProducts => 'لا يوجد منتجات منخفضة المخزون.';

  @override
  String get productName => 'اسم المنتج';

  @override
  String get alertLimit => 'حد التنبيه';

  @override
  String get viewDetails => 'عرض التفاصيل';

  @override
  String get lowStockItems => 'منتجات منخفضة المخزون';

  @override
  String get noLowStockItems => 'لا يوجد منتجات منخفضة';

  @override
  String get stockLevel => 'مستوى المخزون';

  @override
  String get items => 'منتجات';

  @override
  String get searchByInvoiceId => 'بحث برقم الفاتورة';

  @override
  String get invoiceNotFound => 'الفاتورة غير موجودة';

  @override
  String get noCategoriesFound => 'لم يتم العثور على فئات';

  @override
  String get categoryCode => 'كود الفئة';

  @override
  String get addCategory => 'إضافة فئة';

  @override
  String get editCategory => 'تعديل فئة';

  @override
  String get all => 'الكل';

  @override
  String get categoryName => 'اسم الفئة';

  @override
  String get categoryAdded => 'تم إضافة الفئة بنجاح';

  @override
  String get categoryUpdated => 'تم تحديث الفئة بنجاح';

  @override
  String get enterProductName => 'أدخل اسم المنتج';

  @override
  String get sku => 'الباركود';

  @override
  String get enterSku => 'أدخل الباركود';

  @override
  String get buyPrice => 'سعر الشراء';

  @override
  String get sellPrice => 'سعر البيع';

  @override
  String get wholesalePrice => 'سعر الجملة';

  @override
  String get accounting => 'المحاسبة';

  @override
  String get chartOfAccounts => 'شجرة الحسابات';

  @override
  String get generalLedger => 'دفتر الأستاذ';

  @override
  String get trialBalance => 'ميزان المراجعة';

  @override
  String get accountName => 'اسم الحساب';

  @override
  String get accountCode => 'كود الحساب';

  @override
  String get accountType => 'نوع الحساب';

  @override
  String get balance => 'الرصيد';

  @override
  String get debit => 'مدين';

  @override
  String get credit => 'دائن';

  @override
  String get asset => 'أصل';

  @override
  String get liability => 'التزام';

  @override
  String get equity => 'حقوق الملكية';

  @override
  String get expense => 'مصروف';

  @override
  String get addAccount => 'إضافة حساب';

  @override
  String get editAccount => 'تعديل حساب';

  @override
  String get isHeader => 'هل هو حساب رئيسي؟';

  @override
  String get parentAccount => 'الحساب الأب';

  @override
  String get balanceSheet => 'الميزانية العمومية';

  @override
  String get incomeStatement => 'قائمة الدخل';

  @override
  String get expenses => 'المصاريف';

  @override
  String get inventoryAudit => 'جرد المخزون';

  @override
  String get userRoles => 'صلاحيات المستخدمين';

  @override
  String get thermalPrinting => 'الطباعة الحرارية';

  @override
  String get printReceipt => 'طباعة الإيصال';

  @override
  String get fixedAssets => 'الأصول الثابتة';

  @override
  String get cloudSync => 'المزامنة السحابية';

  @override
  String get backupRestore => 'النسخ الاحتياطي والاستعادة';

  @override
  String get totalAssets => 'إجمالي الأصول';

  @override
  String get totalLiabilities => 'إجمالي الالتزامات';

  @override
  String get totalEquity => 'إجمالي حقوق الملكية';

  @override
  String get netIncome => 'صافي الدخل';

  @override
  String get operatingExpenses => 'المصاريف التشغيلية';

  @override
  String get saveSuccess => 'تم الحفظ بنجاح';

  @override
  String get shiftManagement => 'إدارة الوردية';

  @override
  String get openShift => 'فتح وردية';

  @override
  String get closeShift => 'إغلاق الوردية';

  @override
  String get openingCash => 'رصيد الافتتاح';

  @override
  String get closingCash => 'رصيد الإغلاق';

  @override
  String get expectedCash => 'الرصيد المتوقع';

  @override
  String get difference => 'الفارق';

  @override
  String get shiftOpened => 'تم فتح الوردية بنجاح';

  @override
  String get shiftClosed => 'تم إغلاق الوردية بنجاح';

  @override
  String get noOpenShift => 'لا توجد وردية مفتوحة';

  @override
  String get currentShift => 'الوردية الحالية';

  @override
  String get manualJournalEntries => 'قيود يومية يدوية';

  @override
  String get financialYearClosing => 'إغلاق السنة المالية';

  @override
  String get reconciliation => 'تسوية بنكية/نقدية';

  @override
  String get auditLog => 'سجل التدقيق';

  @override
  String get vatReturn => 'إقرار ضريبة القيمة المضافة';

  @override
  String get cashFlow => 'قائمة التدفقات النقدية';

  @override
  String get selectAccount => 'اختر حساب';

  @override
  String get actualBalance => 'الرصيد الفعلي';

  @override
  String get bookBalance => 'الرصيد الدفتري';

  @override
  String get notes => 'ملاحظات';

  @override
  String get reconciliationAdjustment => 'تسوية الفرق';

  @override
  String get cashOverShortAccount => 'حساب عجز وزيادة الصندوق';

  @override
  String get selectAccountError => 'يرجى اختيار حساب';

  @override
  String get enterActualBalanceError => 'يرجى إدخال الرصيد الفعلي';

  @override
  String get reconciliationDifference => 'فارق التسوية';

  @override
  String get vatOnSales => 'ضريبة المخرجات (المبيعات)';

  @override
  String get vatOnPurchases => 'ضريبة المدخلات (المشتريات)';

  @override
  String get netVatPayable => 'صافي الضريبة المستحقة';

  @override
  String get noDataAvailable => 'لا توجد بيانات متاحة للفترة المختارة';

  @override
  String get selectDateRange => 'اختر الفترة الزمنية';

  @override
  String get adminDashboard => 'لوحة تحكم المشرف';

  @override
  String get welcomeAdmin => 'مرحباً بك أيها المشرف';

  @override
  String get adminDashboardDescription =>
      'إدارة عمليات السوبر ماركت الخاصة بك بكل سهولة.';

  @override
  String get manageStaff => 'إدارة الموظفين';

  @override
  String get viewReports => 'عرض التقارير';

  @override
  String get asOf => 'اعتبارًا من';

  @override
  String get balanceSheetBalanced => 'الأصول = الخصوم + حقوق الملكية';

  @override
  String get balanceSheetNotBalanced => 'الميزانية العمومية غير متوازنة!';

  @override
  String get operatingActivities => 'الأنشطة التشغيلية';

  @override
  String get netCashFromOperating => 'صافي النقد من الأنشطة التشغيلية';

  @override
  String get investingActivities => 'الأنشطة الاستثمارية';

  @override
  String get netCashFromInvesting => 'صافي النقد من الأنشطة الاستثمارية';

  @override
  String get financingActivities => 'الأنشطة التمويلية';

  @override
  String get netCashFromFinancing => 'صافي النقد من الأنشطة التمويلية';

  @override
  String get netChangeInCash => 'صافي التغير في النقد';

  @override
  String get beginningCashBalance => 'رصيد النقد أول المدة';

  @override
  String get endingCashBalance => 'رصيد النقد آخر المدة';

  @override
  String get assets => 'الأصول';

  @override
  String get liabilities => 'الالتزامات';

  @override
  String get totalRevenue => 'إجمالي الإيرادات';

  @override
  String get totalExpense => 'إجمالي المصاريف';

  @override
  String get days => 'أيام';

  @override
  String get noPurchasesFound => 'لم يتم العثور على مشتريات';

  @override
  String get walkInSupplier => 'مورد نقدي';

  @override
  String get currencySymbol => 'ر.س';

  @override
  String get backupAndSync => 'النسخ الاحتياطي والمزامنة';

  @override
  String get backupNow => 'نسخ احتياطي الآن';

  @override
  String get localBackup => 'نسخ احتياطي محلي';

  @override
  String get cloudBackup => 'نسخ احتياطي سحابي';

  @override
  String get restoreFromCloud => 'استعادة من السحابة';

  @override
  String get noCloudBackups => 'لا يوجد نسخ احتياطية سحابية';

  @override
  String get restore => 'استعادة';

  @override
  String get restoreFromLocalFile => 'استعادة من ملف محلي';

  @override
  String get pickBackupFile => 'اختر ملف النسخة الاحتياطية';

  @override
  String get confirmRestore => 'تأكيد الاستعادة';

  @override
  String get restoreWarning =>
      'الاستعادة ستؤدي إلى مسح البيانات الحالية. هل أنت متأكد؟';

  @override
  String get simplifiedTaxInvoice => 'فاتورة ضريبية مبسطة';

  @override
  String vatNumber(Object vatNumber) {
    return 'الرقم الضريبي: $vatNumber';
  }

  @override
  String invoiceNumber(Object invoiceNumber) {
    return 'رقم الفاتورة: $invoiceNumber';
  }

  @override
  String paymentMethod(Object paymentMethod) {
    return 'طريقة الدفع: $paymentMethod';
  }

  @override
  String get thankYou => 'شكراً لتعاملكم معنا!';

  @override
  String get closeFinancialYear => 'إغلاق السنة المالية';

  @override
  String get manualEntry => 'قيد يدوي';

  @override
  String get staffManagement => 'إدارة الموظفين';

  @override
  String get noUsersFound => 'لم يتم العثور على مستخدمين';

  @override
  String get addUser => 'إضافة مستخدم';

  @override
  String get editUser => 'تعديل مستخدم';

  @override
  String get deleteUser => 'حذف مستخدم';

  @override
  String confirmDeleteUser(Object name) {
    return 'هل أنت متأكد من حذف المستخدم $name؟';
  }

  @override
  String get leaveEmptyToKeep => 'اتركه فارغاً للحفاظ على كلمة المرور الحالية';

  @override
  String get role => 'الدور/الصلاحية';

  @override
  String get customerStatement => 'كشف حساب عميل';

  @override
  String get noTransactionsFound => 'لم يتم العثور على عمليات';

  @override
  String get sale => 'بيعة';

  @override
  String get payment => 'دفعة';

  @override
  String get cart => 'السلة';

  @override
  String get checkout => 'إتمام الشراء';

  @override
  String get syncStatus => 'حالة المزامنة';

  @override
  String get allChangesSynced => 'تم مزامنة جميع التغييرات';

  @override
  String unsyncedChanges(Object count) {
    return '$count تغييرات غير متزامنة';
  }

  @override
  String get syncNow => 'مزامنة الآن';

  @override
  String lastSync(Object time) {
    return 'آخر مزامنة: $time';
  }

  @override
  String get name => 'الاسم';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get status => 'الحالة';

  @override
  String get warehouse => 'المستودع';

  @override
  String get batchNumber => 'رقم الدفعة';

  @override
  String get expiryDate => 'تاريخ الانتهاء';

  @override
  String get draft => 'مسودة';

  @override
  String get ordered => 'مطلوب';

  @override
  String get received => 'مستلم';

  @override
  String get cancelled => 'ملغي';

  @override
  String get selectWarehouse => 'اختر المستودع';

  @override
  String get noWarehousesFound => 'لم يتم العثور على مستودعات';

  @override
  String get addWarehouse => 'إضافة مستودع';

  @override
  String get warehouseName => 'اسم المستودع';

  @override
  String get errorLoadingData => 'خطأ في تحميل البيانات';

  @override
  String get from => 'من';

  @override
  String get to => 'إلى';

  @override
  String get whatWouldYouLikeToDo => 'ماذا تود أن تفعل؟';

  @override
  String get downloadPdfInvoice => 'تحميل الفاتورة PDF';

  @override
  String get done => 'تم';

  @override
  String get vatReport => 'تقرير ضريبة القيمة المضافة';

  @override
  String get vatSummary => 'ملخص الضريبة';

  @override
  String get totalOutputVat => 'إجمالي ضريبة المخرجات';

  @override
  String get totalInputVat => 'إجمالي ضريبة المدخلات';

  @override
  String get noItemsFound => 'لم يتم العثور على أصناف';

  @override
  String get unknownProduct => 'منتج غير معروف';

  @override
  String get viewInvoice => 'عرض الفاتورة';

  @override
  String get confirmDeleteCategory =>
      'هل أنت متأكد من حذف هذه الفئة؟ سيؤدي هذا إلى منع الوصول إلى المنتجات المرتبطة بها.';

  @override
  String get categoryHasProductsError =>
      'لا يمكن حذف الفئة لأنها مرتبطة بمنتجات موجودة.';

  @override
  String get deleteCategory => 'حذف فئة';

  @override
  String get customerStatementTooltip => 'كشف حساب';

  @override
  String get newPurchaseReturn => 'مرتجع مشتريات جديد';

  @override
  String get selectPurchase => 'اختر مشتريات';

  @override
  String get selectAPurchaseToContinue => 'اختر مشتريات للمتابعة';

  @override
  String get processReturn => 'إتمام المرتجع';

  @override
  String get returnProcessedSuccessfully => 'تم إتمام المرتجع بنجاح';

  @override
  String get noReturnsYet => 'لا يوجد مرتجعات بعد';

  @override
  String get newSalesReturn => 'مرتجع مبيعات جديد';

  @override
  String get selectSale => 'اختر بيعة';

  @override
  String get failedToSaveProduct => 'فشل حفظ المنتج';

  @override
  String get failedToSaveCategory => 'فشل حفظ الفئة';

  @override
  String get failedToDeleteProduct => 'فشل حذف المنتج';

  @override
  String deleteProductConfirmation(Object productName) {
    return 'هل أنت متأكد أنك تريد حذف $productName؟';
  }

  @override
  String get failedToSavePurchase => 'فشل حفظ المشتريات';

  @override
  String get selectASaleToContinue => 'اختر بيعة للمتابعة';
}
