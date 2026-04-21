import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/theme/app_theme.dart';
import 'package:supermarket/core/theme/theme_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart' as di;
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:supermarket/presentation/features/sales/sales_invoice_page.dart';
import 'package:supermarket/presentation/features/purchases/add_purchase_page.dart';

// Import all pages
import 'package:supermarket/presentation/features/auth/login_page.dart';
import 'package:supermarket/presentation/features/auth/staff_management_page.dart';
import 'package:supermarket/presentation/features/home/home_page.dart';
import 'package:supermarket/presentation/features/home/low_stock_products_page.dart';
import 'package:supermarket/presentation/features/pos/pos_page.dart';
import 'package:supermarket/presentation/features/sales/sales_history_page.dart';
import 'package:supermarket/presentation/features/sales/sales_return_page.dart';
import 'package:supermarket/presentation/features/sales/add_sales_return_page.dart';
import 'package:supermarket/presentation/features/products/products_page.dart';
import 'package:supermarket/presentation/features/products/categories_page.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/presentation/features/accounting/trial_balance_page.dart';
import 'package:supermarket/presentation/features/accounting/chart_of_accounts_page.dart';
import 'package:supermarket/presentation/features/accounting/general_ledger_page.dart';
import 'package:supermarket/presentation/features/accounting/expenses_page.dart';
import 'package:supermarket/presentation/features/accounting/accounting_periods_page.dart';
import 'package:supermarket/presentation/features/accounting/manual_journal_entry_page.dart';
import 'package:supermarket/presentation/features/accounting/manual_voucher_page.dart';
import 'package:supermarket/presentation/features/accounting/reconciliation_page.dart';
import 'package:supermarket/presentation/features/accounting/shifts_page.dart';
import 'package:supermarket/presentation/features/accounting/income_statement_page.dart';
import 'package:supermarket/presentation/features/accounting/balance_sheet_page.dart';
import 'package:supermarket/presentation/features/accounting/fixed_assets_page.dart';
import 'package:supermarket/presentation/features/accounting/cost_centers_page.dart';
import 'package:supermarket/presentation/features/reports/inventory_reports_screen.dart';
import 'package:supermarket/presentation/features/reports/sales_reports_page.dart';
import 'package:supermarket/presentation/features/reports/vat_report_page.dart';
import 'package:supermarket/presentation/features/reports/audit_log_page.dart';
import 'package:supermarket/presentation/features/reports/printer_settings_page.dart';
import 'package:supermarket/presentation/features/reports/product_profitability_page.dart';
import 'package:supermarket/presentation/features/returns/returns_page.dart';
import 'package:supermarket/presentation/features/returns/create_return_page.dart';
import 'package:supermarket/presentation/features/settings/backup_page.dart';
import 'package:supermarket/presentation/features/settings/permissions_management_page.dart';
import 'package:supermarket/presentation/features/customers/customer_statement_provider.dart';
import 'package:supermarket/presentation/features/inventory/stock_transfer_page.dart';
import 'package:supermarket/presentation/features/hr/employees_page.dart';
import 'package:supermarket/presentation/features/hr/payroll_page.dart';
import 'package:supermarket/presentation/features/products/unit_conversion_page.dart';
import 'package:supermarket/presentation/features/inventory/warehouse_management_page.dart';
import 'package:supermarket/presentation/features/inventory/stock_take_page.dart';
import 'package:supermarket/presentation/features/dashboard/dashboard_page.dart';
import 'package:supermarket/presentation/features/dashboard/admin_dashboard_page.dart';
import 'package:supermarket/presentation/features/accounting/cash_flow_page.dart';
import 'package:supermarket/presentation/features/accounting/checks_page.dart';
import 'package:supermarket/presentation/features/settings/currency_rates_page.dart';
import 'package:supermarket/presentation/features/reports/inventory_audit_page.dart';
import 'package:supermarket/presentation/features/customers/customers_page.dart';
import 'package:supermarket/presentation/features/customers/customer_statement_page.dart';
import 'package:supermarket/presentation/features/suppliers/suppliers_page.dart';
import 'package:supermarket/presentation/features/suppliers/supplier_statement_page.dart';
import 'package:supermarket/presentation/features/purchases/purchases_page.dart';
import 'package:supermarket/presentation/features/purchases/purchase_details_page.dart';
import 'package:supermarket/presentation/features/purchases/purchase_return_page.dart';
import 'package:supermarket/presentation/features/purchases/add_purchase_return_page.dart';
import 'package:supermarket/presentation/features/purchases/purchase_provider.dart';

// Services & Providers Imports
import 'package:supermarket/core/services/shift_service.dart';
import 'package:supermarket/core/services/hr_service.dart';
import 'package:supermarket/core/services/stock_transfer_service.dart';
import 'package:supermarket/core/services/asset_service.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/purchase_service.dart';
import 'package:supermarket/presentation/features/accounting/shifts_provider.dart';
import 'package:supermarket/presentation/features/accounting/asset_provider.dart';
import 'package:supermarket/presentation/features/hr/hr_provider.dart';
import 'package:supermarket/presentation/features/hr/payroll_provider.dart';
import 'package:supermarket/presentation/features/inventory/stock_transfer_provider.dart';
import 'package:supermarket/presentation/features/products/products_provider.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    di.init();

    final authProvider = di.sl<AuthProvider>();
    await authProvider.seedAdmin();

    final accountingService = di.sl<AccountingService>();
    await accountingService.seedDefaultAccounts();

    runApp(const MyApp());
  } catch (e, stack) {
    debugPrint("Critical startup error: $e");
    debugPrint(stack.toString());
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Text("Error starting app: $e\nPlease restart.")),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final db = di.sl<AppDatabase>();
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<AccountingService>.value(value: di.sl<AccountingService>()),
        ChangeNotifierProvider(create: (_) => di.sl<ThemeProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<AuthProvider>()),
        ChangeNotifierProvider(create: (_) => AccountingProvider(db)),
        ChangeNotifierProvider(create: (_) => di.sl<ProductsProvider>()),
        ChangeNotifierProvider(
          create: (_) => PurchaseProvider(db, di.sl<PurchaseService>()),
        ),
        ChangeNotifierProvider(create: (_) => ShiftProvider(ShiftService(db))),
        ChangeNotifierProvider(create: (_) => HRProvider(HRService(db))),
        ChangeNotifierProvider(create: (_) => PayrollProvider(HRService(db))),
        ChangeNotifierProvider(
          create: (_) => StockTransferProvider(StockTransferService(db)),
        ),
        ChangeNotifierProvider(create: (_) => AssetProvider(AssetService(db))),
        ChangeNotifierProvider(create: (_) => CustomerStatementProvider()),
      ],
      child: Builder(
        builder: (context) {
          final themeProvider = Provider.of<ThemeProvider>(context);
          final router = _createRouter(context);
          return MaterialApp.router(
            title: 'Supermarket ERP',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ar'),
          );
        },
      ),
    );
  }

  GoRouter _createRouter(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isLoggingIn = state.matchedLocation == '/login';

        if (!isAuthenticated && !isLoggingIn) {
          return '/login';
        }

        if (isAuthenticated && isLoggingIn) {
          return '/';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/admin-dashboard',
          builder: (context, state) => const AdminDashboardPage(),
        ),
        GoRoute(path: '/pos', builder: (context, state) => const PosPage()),

        // Sales & Returns
        GoRoute(
          path: '/sales',
          builder: (context, state) => const SalesHistoryPage(),
        ),
        GoRoute(
          path: '/sales/invoice',
          builder: (context, state) => const SalesInvoicePage(),
        ),
        GoRoute(
          path: '/sales/returns',
          builder: (context, state) => const SalesReturnPage(),
        ),
        GoRoute(
          path: '/sales/returns/new',
          builder: (context, state) {
            final saleId = state.extra as String?;
            return AddSalesReturnPage(saleId: saleId);
          },
        ),
        GoRoute(
          path: '/returns',
          builder: (context, state) => const ReturnsPage(),
        ),
        GoRoute(
          path: '/returns/new',
          builder: (context, state) =>
              const CreateReturnPage(type: ReturnType.sale),
        ),

        // Products & Inventory
        GoRoute(
          path: '/products',
          builder: (context, state) => const ProductsPage(),
        ),
        GoRoute(
          path: '/products/unit-conversion/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final name = state.extra as String? ?? 'Product';
            return UnitConversionPage(productId: id, productName: name);
          },
        ),
        GoRoute(
          path: '/categories',
          builder: (context, state) => const CategoriesPage(),
        ),
        GoRoute(
          path: '/low-stock',
          builder: (context, state) => const LowStockProductsPage(),
        ),
        GoRoute(
          path: '/inventory/transfer',
          builder: (context, state) => const StockTransferPage(),
        ),
        GoRoute(
          path: '/inventory/warehouses',
          builder: (context, state) => const WarehouseManagementPage(),
        ),
        GoRoute(
          path: '/inventory/stock-take',
          builder: (context, state) => const StockTakePage(),
        ),

        // HR
        GoRoute(
          path: '/hr/employees',
          builder: (context, state) => const EmployeesPage(),
        ),
        GoRoute(
          path: '/hr/payroll',
          builder: (context, state) => const PayrollPage(),
        ),

        // Customers & Suppliers
        GoRoute(
          path: '/customers',
          builder: (context, state) => const CustomersPage(),
        ),
        GoRoute(
          path: '/customers/statement/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return CustomerStatementPage(customerId: id);
          },
        ),
        GoRoute(
          path: '/suppliers',
          builder: (context, state) => const SuppliersPage(),
        ),
        GoRoute(
          path: '/suppliers/statement/:id',
          builder: (context, state) {
            final supplier = state.extra as Supplier;
            return SupplierStatementPage(supplier: supplier);
          },
        ),

        // Purchases
        GoRoute(
          path: '/purchases',
          builder: (context, state) => const PurchasesPage(),
        ),
        GoRoute(
          path: '/purchases/new',
          builder: (context, state) => const AddPurchasePage(),
        ),
        GoRoute(
          path: '/purchases/details/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return PurchaseDetailsPage(purchaseId: id);
          },
        ),
        GoRoute(
          path: '/purchases/returns',
          builder: (context, state) => const PurchaseReturnPage(),
        ),
        GoRoute(
          path: '/purchases/returns/new',
          builder: (context, state) => const AddPurchaseReturnPage(),
        ),

        // Accounting
        GoRoute(
          path: '/accounting/coa',
          builder: (context, state) => const ChartOfAccountsPage(),
        ),
        GoRoute(
          path: '/accounting/general-ledger',
          builder: (context, state) => const GeneralLedgerPage(),
        ),
        GoRoute(
          path: '/accounting/balance-sheet',
          builder: (context, state) => const BalanceSheetPage(),
        ),
        GoRoute(
          path: '/accounting/income-statement',
          builder: (context, state) => const IncomeStatementPage(),
        ),
        GoRoute(
          path: '/accounting/cash-flow',
          builder: (context, state) => const CashFlowPage(),
        ),
        GoRoute(
          path: '/accounting/trial-balance',
          builder: (context, state) => const TrialBalancePage(),
        ),
        GoRoute(
          path: '/accounting/expenses',
          builder: (context, state) => const ExpensesPage(),
        ),
        GoRoute(
          path: '/accounting/fixed-assets',
          builder: (context, state) => const FixedAssetsPage(),
        ),
        GoRoute(
          path: '/accounting/manual-journal',
          builder: (context, state) => const ManualJournalEntryPage(),
        ),
        GoRoute(
          path: '/accounting/manual-voucher',
          builder: (context, state) {
            final isReceipt = state.uri.queryParameters['receipt'] != 'false';
            return ManualVoucherPage(isReceipt: isReceipt);
          },
        ),
        GoRoute(
          path: '/accounting/reconciliation',
          builder: (context, state) => const ReconciliationPage(),
        ),
        GoRoute(
          path: '/accounting/periods',
          builder: (context, state) => const AccountingPeriodsPage(),
        ),
        GoRoute(
          path: '/accounting/shifts',
          builder: (context, state) => const ShiftsPage(),
        ),
        GoRoute(
          path: '/accounting/checks',
          builder: (context, state) => const ChecksPage(),
        ),
        GoRoute(
          path: '/accounting/cost-centers',
          builder: (context, state) => const CostCentersPage(),
        ),

        // Reports
        GoRoute(
          path: '/reports/sales',
          builder: (context, state) => const SalesReportsPage(),
        ),
        GoRoute(
          path: '/reports/profitability',
          builder: (context, state) => const ProductProfitabilityPage(),
        ),
        GoRoute(
          path: '/reports/inventory',
          builder: (context, state) => const InventoryReportsScreen(),
        ),
        GoRoute(
          path: '/reports/inventory-audit',
          builder: (context, state) => const InventoryAuditPage(),
        ),
        GoRoute(
          path: '/reports/vat',
          builder: (context, state) => const VatReportPage(),
        ),
        GoRoute(
          path: '/reports/audit',
          builder: (context, state) => const AuditLogPage(),
        ),

        // Settings
        GoRoute(
          path: '/users',
          builder: (context, state) => const StaffManagementPage(),
        ),
        GoRoute(
          path: '/settings/backup',
          builder: (context, state) => const BackupPage(),
        ),
        GoRoute(
          path: '/settings/permissions',
          builder: (context, state) => const PermissionsManagementPage(),
        ),
        GoRoute(
          path: '/settings/currency-rates',
          builder: (context, state) => const CurrencyRatesPage(),
        ),
        GoRoute(
          path: '/settings/printer',
          builder: (context, state) => const PrinterSettingsPage(),
        ),
      ],
    );
  }
}
