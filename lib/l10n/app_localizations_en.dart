// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Accounting App';

  @override
  String get home => 'Home';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get pos => 'POS';

  @override
  String get products => 'Products';

  @override
  String get categories => 'Categories';

  @override
  String get customers => 'Customers';

  @override
  String get suppliers => 'Suppliers';

  @override
  String get purchases => 'Purchases';

  @override
  String get returns => 'Returns';

  @override
  String get reports => 'Reports';

  @override
  String get sales => 'Sales History';

  @override
  String get logout => 'Logout';

  @override
  String get backupDb => 'Backup DB';

  @override
  String get welcome => 'Welcome';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get login => 'Login';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get accountingSystem => 'Accounting System';

  @override
  String get loginButton => 'LOGIN';

  @override
  String get loginHint => 'Hint: admin / 123';

  @override
  String get invalidCredentials => 'Invalid credentials';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get seedProducts => 'Seed Products';

  @override
  String get viewSales => 'View Sales';

  @override
  String get overview => 'Overview';

  @override
  String get totalSales => 'Total Sales';

  @override
  String get todaySales => 'Today\'s Sales';

  @override
  String get revenue => 'Revenue';

  @override
  String get pendingSync => 'Pending Sync';

  @override
  String get seedDataAdded => 'Seed data added!';

  @override
  String get wholesale => 'Wholesale';

  @override
  String get clearCart => 'Clear Cart';

  @override
  String get cartEmpty => 'Cart is empty';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get discount => 'Discount';

  @override
  String get tax => 'Tax (15%)';

  @override
  String get total => 'Total';

  @override
  String get proceedToCheckout => 'PROCEED TO CHECKOUT';

  @override
  String get completePayment => 'Complete Payment';

  @override
  String get selectCustomer => 'Select Customer (Optional)';

  @override
  String get cashPayment => 'Cash Payment';

  @override
  String get creditSale => 'Credit Sale';

  @override
  String get selectCustomerError => 'Please select a customer for credit sale';

  @override
  String get customerNameHint => 'Start typing to search or add new customer';

  @override
  String get addCustomerForCredit => 'Add New Customer for Credit Sale';

  @override
  String get searchProducts => 'Search products...';

  @override
  String get noProductsFound => 'No products found';

  @override
  String get skuLabel => 'SKU';

  @override
  String get stockLabel => 'Stock';

  @override
  String get stock => 'Stock';

  @override
  String get category => 'Category';

  @override
  String get price => 'Price';

  @override
  String get productAdded => 'Product added successfully';

  @override
  String get productUpdated => 'Product updated successfully';

  @override
  String get searchCustomers => 'Search customers...';

  @override
  String get noCustomersFound => 'No customers found';

  @override
  String get noPhone => 'No phone';

  @override
  String balanceLabel(Object balance) {
    return 'Bal: $balance';
  }

  @override
  String limitLabel(Object limit) {
    return 'Limit: $limit';
  }

  @override
  String get customerAdded => 'Customer added successfully';

  @override
  String get customerUpdated => 'Customer updated successfully';

  @override
  String get addCustomer => 'Add Customer';

  @override
  String get editCustomer => 'Edit Customer';

  @override
  String get customerName => 'Customer Name';

  @override
  String get enterNameError => 'Please enter a name';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get creditLimitLabel => 'Credit Limit';

  @override
  String get totalCustomers => 'Total Customers';

  @override
  String get searchSuppliers => 'Search suppliers...';

  @override
  String get noSuppliersFound => 'No suppliers found';

  @override
  String get noContactPerson => 'No contact person';

  @override
  String get supplierAdded => 'Supplier added successfully';

  @override
  String get supplierUpdated => 'Supplier updated successfully';

  @override
  String get addSupplier => 'Add Supplier';

  @override
  String get editSupplier => 'Edit Supplier';

  @override
  String get supplierName => 'Supplier Name';

  @override
  String get contactPerson => 'Contact Person';

  @override
  String get purchasesHistory => 'Purchases History';

  @override
  String get noPurchases => 'No purchases recorded yet.';

  @override
  String invoiceLabel(Object invoice) {
    return 'Invoice: $invoice';
  }

  @override
  String supplierLabel(Object supplier) {
    return 'Supplier: $supplier';
  }

  @override
  String dateLabel(Object date) {
    return 'Date: $date';
  }

  @override
  String get unknown => 'Unknown';

  @override
  String get newPurchase => 'New Purchase';

  @override
  String get purchaseDetails => 'Purchase Details';

  @override
  String get loading => 'Loading...';

  @override
  String get totalPaid => 'Total Paid';

  @override
  String get newPurchaseInvoice => 'New Purchase Invoice';

  @override
  String get selectSupplier => 'Select Supplier';

  @override
  String get invoiceNumberLabel => 'Invoice Number';

  @override
  String get noProductsAdded => 'No products added yet.';

  @override
  String qtyAtPrice(Object price, Object qty) {
    return 'Qty: $qty @ $price';
  }

  @override
  String get savePurchase => 'SAVE PURCHASE';

  @override
  String get purchaseSaved => 'Purchase saved successfully!';

  @override
  String get addProductToPurchase => 'Add Product to Purchase';

  @override
  String get productLabel => 'Product';

  @override
  String get quantityLabel => 'Quantity';

  @override
  String get buyPriceLabel => 'Buy Price';

  @override
  String get noSalesFound => 'No sales found';

  @override
  String saleIdLabel(Object id) {
    return 'Sale #$id';
  }

  @override
  String get synced => 'Synced';

  @override
  String get pending => 'Pending';

  @override
  String get saleDetails => 'Sale Details';

  @override
  String get newSale => 'New Sale';

  @override
  String get returnsManagement => 'Returns Management';

  @override
  String get salesReturns => 'Sales Returns';

  @override
  String get purchaseReturns => 'Purchase Returns';

  @override
  String get newReturn => 'New Return';

  @override
  String get noReturnsFound => 'No returns found.';

  @override
  String returnIdLabel(Object id) {
    return 'Return ID: $id';
  }

  @override
  String amountReturnedLabel(Object amount) {
    return 'Amount: $amount';
  }

  @override
  String get createReturn => 'Create Return';

  @override
  String get fromSale => 'From a Sale';

  @override
  String get fromPurchase => 'From a Purchase';

  @override
  String txLabel(Object id) {
    return 'Tx: $id';
  }

  @override
  String get financialReports => 'Financial Reports';

  @override
  String get totalProfitLoss => 'Total Profit/Loss';

  @override
  String get totalSalesRevenue => 'Total Sales (Revenue)';

  @override
  String get totalPurchasesExpenses => 'Total Purchases (Expenses)';

  @override
  String get grossProfit => 'Gross Profit';

  @override
  String get outstandingBalances => 'Outstanding Balances';

  @override
  String get customerDebts => 'Customer Debts';

  @override
  String get supplierDebts => 'Supplier Debts';

  @override
  String get inventoryValue => 'Inventory Value';

  @override
  String get totalStockValue => 'Total Stock Value (at Buy Price)';

  @override
  String get addProduct => 'Add Product';

  @override
  String get editProduct => 'Edit Product';

  @override
  String get productNameLabel => 'Product Name';

  @override
  String get skuBarcodeLabel => 'SKU/Barcode';

  @override
  String get enterSkuError => 'Please enter an SKU';

  @override
  String get categoryLabel => 'Category';

  @override
  String get sellPriceLabel => 'Sell Price';

  @override
  String get initialStockLabel => 'Initial Stock';

  @override
  String get payAmount => 'Pay Amount';

  @override
  String get paymentAmount => 'Payment Amount';

  @override
  String get paymentSuccess => 'Payment recorded successfully';

  @override
  String get enterAmountError => 'Please enter a valid amount';

  @override
  String get scanBarcode => 'Scan Barcode';

  @override
  String get inventoryReports => 'Inventory Reports';

  @override
  String get lowStockProducts => 'Low Stock Products';

  @override
  String get noLowStockProducts => 'No products with low stock.';

  @override
  String get productName => 'Product Name';

  @override
  String get alertLimit => 'Alert Limit';

  @override
  String get viewDetails => 'View Details';

  @override
  String get lowStockItems => 'items with low stock';

  @override
  String get noLowStockItems => 'No low stock items';

  @override
  String get stockLevel => 'Stock Level';

  @override
  String get items => 'Items';

  @override
  String get searchByInvoiceId => 'Search by Invoice ID';

  @override
  String get invoiceNotFound => 'Invoice not found';

  @override
  String get noCategoriesFound => 'No categories found';

  @override
  String get categoryCode => 'Category Code';

  @override
  String get addCategory => 'Add Category';

  @override
  String get editCategory => 'Edit Category';

  @override
  String get all => 'All';

  @override
  String get categoryName => 'Category Name';

  @override
  String get categoryAdded => 'Category added successfully';

  @override
  String get categoryUpdated => 'Category updated successfully';

  @override
  String get enterProductName => 'Enter product name';

  @override
  String get sku => 'SKU';

  @override
  String get enterSku => 'Enter SKU';

  @override
  String get buyPrice => 'Buy Price';

  @override
  String get sellPrice => 'Sell Price';

  @override
  String get wholesalePrice => 'Wholesale Price';

  @override
  String get costCenters => 'Cost Centers';

  @override
  String get addCostCenter => 'Add Cost Center';

  @override
  String get code => 'Code';

  @override
  String get noCostCentersFound => 'No cost centers found';

  @override
  String get accounting => 'Accounting';

  @override
  String get chartOfAccounts => 'Chart of Accounts';

  @override
  String get generalLedger => 'General Ledger';

  @override
  String get trialBalance => 'Trial Balance';

  @override
  String get accountName => 'Account Name';

  @override
  String get accountCode => 'Account Code';

  @override
  String get accountType => 'Account Type';

  @override
  String get balance => 'Balance';

  @override
  String get debit => 'Debit';

  @override
  String get credit => 'Credit';

  @override
  String get asset => 'Asset';

  @override
  String get liability => 'Liability';

  @override
  String get equity => 'Equity';

  @override
  String get expense => 'Expense';

  @override
  String get addAccount => 'Add Account';

  @override
  String get editAccount => 'Edit Account';

  @override
  String get isHeader => 'Is Header?';

  @override
  String get parentAccount => 'Parent Account';

  @override
  String get balanceSheet => 'Balance Sheet';

  @override
  String get incomeStatement => 'Income Statement';

  @override
  String get expenses => 'Expenses';

  @override
  String get inventoryAudit => 'Inventory Audit';

  @override
  String get userRoles => 'User Roles';

  @override
  String get thermalPrinting => 'Thermal Printing';

  @override
  String get printReceipt => 'Print Receipt';

  @override
  String get fixedAssets => 'Fixed Assets';

  @override
  String get cloudSync => 'Cloud Sync';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get totalAssets => 'Total Assets';

  @override
  String get totalLiabilities => 'Total Liabilities';

  @override
  String get totalEquity => 'Total Equity';

  @override
  String get netIncome => 'Net Income';

  @override
  String get operatingExpenses => 'Operating Expenses';

  @override
  String get saveSuccess => 'Saved successfully';

  @override
  String get shiftManagement => 'Shift Management';

  @override
  String get openShift => 'Open Shift';

  @override
  String get closeShift => 'Close Shift';

  @override
  String get openingCash => 'Opening Cash';

  @override
  String get closingCash => 'Closing Cash';

  @override
  String get expectedCash => 'Expected Cash';

  @override
  String get difference => 'Difference';

  @override
  String get shiftOpened => 'Shift opened successfully';

  @override
  String get shiftClosed => 'Shift closed successfully';

  @override
  String get noOpenShift => 'No open shift found';

  @override
  String get currentShift => 'Current Shift';

  @override
  String get manualJournalEntries => 'Manual Journal Entries';

  @override
  String get financialYearClosing => 'Financial Year Closing';

  @override
  String get reconciliation => 'Bank/Cash Reconciliation';

  @override
  String get auditLog => 'Audit Log';

  @override
  String get vatReturn => 'VAT Return Report';

  @override
  String get cashFlow => 'Cash Flow Statement';

  @override
  String get selectAccount => 'Select Account';

  @override
  String get actualBalance => 'Actual Balance';

  @override
  String get bookBalance => 'Book Balance';

  @override
  String get notes => 'Notes';

  @override
  String get reconciliationAdjustment => 'Reconciliation adjustment';

  @override
  String get cashOverShortAccount => 'Cash Over/Short Account';

  @override
  String get selectAccountError => 'Please select an account';

  @override
  String get enterActualBalanceError => 'Please enter the actual balance';

  @override
  String get reconciliationDifference => 'Reconciliation Difference';

  @override
  String get vatOnSales => 'VAT on Sales (Output VAT)';

  @override
  String get vatOnPurchases => 'VAT on Purchases (Input VAT)';

  @override
  String get netVatPayable => 'Net VAT Payable';

  @override
  String get noDataAvailable => 'No data available for the selected period';

  @override
  String get selectDateRange => 'Select Date Range';

  @override
  String get adminDashboard => 'Admin Dashboard';

  @override
  String get welcomeAdmin => 'Welcome Admin';

  @override
  String get adminDashboardDescription =>
      'Manage your supermarket operations with ease.';

  @override
  String get manageStaff => 'Manage Staff';

  @override
  String get viewReports => 'View Reports';

  @override
  String get asOf => 'As of';

  @override
  String get balanceSheetBalanced => 'Assets = Liabilities + Equity';

  @override
  String get balanceSheetNotBalanced => 'Balance Sheet is not balanced!';

  @override
  String get operatingActivities => 'Operating Activities';

  @override
  String get netCashFromOperating => 'Net Cash From Operating Activities';

  @override
  String get investingActivities => 'Investing Activities';

  @override
  String get netCashFromInvesting => 'Net Cash From Investing Activities';

  @override
  String get financingActivities => 'Financing Activities';

  @override
  String get netCashFromFinancing => 'Net Cash From Financing Activities';

  @override
  String get netChangeInCash => 'Net Change In Cash';

  @override
  String get beginningCashBalance => 'Beginning Cash Balance';

  @override
  String get endingCashBalance => 'Ending Cash Balance';

  @override
  String get assets => 'Assets';

  @override
  String get liabilities => 'Liabilities';

  @override
  String get totalRevenue => 'Total Revenue';

  @override
  String get totalExpense => 'Total Expense';

  @override
  String get days => 'Days';

  @override
  String get noPurchasesFound => 'No Purchases Found';

  @override
  String get walkInSupplier => 'Walk-in Supplier';

  @override
  String get currencySymbol => 'SAR';

  @override
  String get backupAndSync => 'Backup and Sync';

  @override
  String get backupNow => 'Backup Now';

  @override
  String get localBackup => 'Local Backup';

  @override
  String get cloudBackup => 'Cloud Backup';

  @override
  String get restoreFromCloud => 'Restore from Cloud';

  @override
  String get noCloudBackups => 'No Cloud Backups';

  @override
  String get restore => 'Restore';

  @override
  String get restoreFromLocalFile => 'Restore from Local File';

  @override
  String get pickBackupFile => 'Pick Backup File';

  @override
  String get confirmRestore => 'Confirm Restore';

  @override
  String get restoreWarning =>
      'Restoring will overwrite current data. Are you sure?';

  @override
  String get simplifiedTaxInvoice => 'Simplified Tax Invoice';

  @override
  String vatNumber(Object vatNumber) {
    return 'VAT Number: $vatNumber';
  }

  @override
  String invoiceNumber(Object invoiceNumber) {
    return 'Invoice No: $invoiceNumber';
  }

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get date => 'Date';

  @override
  String get supplier => 'Supplier';

  @override
  String get cash => 'Cash';

  @override
  String get sale => 'Sale';

  @override
  String get purchase => 'Purchase';

  @override
  String get purchaseId => 'Purchase ID';

  @override
  String get totalReturnAmount => 'Total Return Amount';

  @override
  String get purchaseNotFound => 'Purchase not found';

  @override
  String get thankYou => 'Thank you for your business!';

  @override
  String get closeFinancialYear => 'Close Financial Year';

  @override
  String get manualEntry => 'Manual Entry';

  @override
  String get staffManagement => 'Staff Management';

  @override
  String get noUsersFound => 'No users found';

  @override
  String get addUser => 'Add User';

  @override
  String get editUser => 'Edit User';

  @override
  String get deleteUser => 'Delete User';

  @override
  String confirmDeleteUser(Object name) {
    return 'Are you sure you want to delete user $name?';
  }

  @override
  String get leaveEmptyToKeep => 'Leave empty to keep current password';

  @override
  String get role => 'Role/Permission';

  @override
  String get customerStatement => 'Customer Statement';

  @override
  String get noTransactionsFound => 'No transactions found';

  @override
  String get payment => 'Payment';

  @override
  String get cart => 'Cart';

  @override
  String get checkout => 'Checkout';

  @override
  String get syncStatus => 'Sync Status';

  @override
  String get allChangesSynced => 'All changes synced';

  @override
  String unsyncedChanges(Object count) {
    return '$count unsynced changes';
  }

  @override
  String get syncNow => 'Sync Now';

  @override
  String lastSync(Object time) {
    return 'Last Sync: $time';
  }

  @override
  String get name => 'Name';

  @override
  String get fullName => 'Full Name';

  @override
  String get status => 'Status';

  @override
  String get warehouse => 'Warehouse';

  @override
  String get batchNumber => 'Batch Number';

  @override
  String get expiryDate => 'Expiry Date';

  @override
  String get draft => 'Draft';

  @override
  String get ordered => 'Ordered';

  @override
  String get received => 'Received';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get selectWarehouse => 'Select Warehouse';

  @override
  String get noWarehousesFound => 'No warehouses found';

  @override
  String get addWarehouse => 'Add Warehouse';

  @override
  String get warehouseName => 'Warehouse Name';

  @override
  String get errorLoadingData => 'Error loading data';

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String get whatWouldYouLikeToDo => 'What would you like to do?';

  @override
  String get downloadPdfInvoice => 'Download PDF Invoice';

  @override
  String get done => 'Done';

  @override
  String get vatReport => 'VAT Report';

  @override
  String get vatSummary => 'VAT Summary';

  @override
  String get totalOutputVat => 'Total Output VAT';

  @override
  String get totalInputVat => 'Total Input VAT';

  @override
  String get noItemsFound => 'No items found';

  @override
  String get unknownProduct => 'Unknown Product';

  @override
  String get viewInvoice => 'View Invoice';

  @override
  String get confirmDeleteCategory =>
      'Are you sure you want to delete this category? This will prevent access to associated products.';

  @override
  String get categoryHasProductsError =>
      'Cannot delete category because it is associated with existing products.';

  @override
  String get deleteCategory => 'Delete Category';

  @override
  String get customerStatementTooltip => 'Account Statement';

  @override
  String get newPurchaseReturn => 'New Purchase Return';

  @override
  String get selectPurchase => 'Select Purchase';

  @override
  String get selectAPurchaseToContinue => 'Select a purchase to continue';

  @override
  String get processReturn => 'Process Return';

  @override
  String get returnProcessedSuccessfully => 'Return processed successfully';

  @override
  String get noReturnsYet => 'No returns yet';

  @override
  String get newSalesReturn => 'New Sales Return';

  @override
  String get selectSale => 'Select Sale';

  @override
  String get failedToSaveProduct => 'Failed to save product';

  @override
  String get failedToSaveCategory => 'Failed to save category';

  @override
  String get failedToDeleteProduct => 'Failed to delete product';

  @override
  String deleteProductConfirmation(Object productName) {
    return 'Are you sure you want to delete $productName?';
  }

  @override
  String get failedToSavePurchase => 'Failed to save purchase';

  @override
  String get selectASaleToContinue => 'Select a sale to continue';

  @override
  String get unit => 'Unit';

  @override
  String get cartonUnit => 'Carton Unit';

  @override
  String get piecesPerCarton => 'Pieces per Carton';

  @override
  String get baseUnit => 'Base Unit';

  @override
  String get isCarton => 'Is Carton?';
}
