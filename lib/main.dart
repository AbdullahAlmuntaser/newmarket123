import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/theme/app_theme.dart';
import 'package:supermarket/core/theme/theme_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart' as di;
import 'package:supermarket/l10n/app_localizations.dart';
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
import 'package:supermarket/presentation/features/purchases/purchases_page.dart';
import 'package:supermarket/presentation/features/purchases/add_purchase_page.dart';
import 'package:supermarket/presentation/features/purchases/purchase_return_page.dart';
import 'package:supermarket/presentation/features/purchases/add_purchase_return_page.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/presentation/features/accounting/trial_balance_page.dart';
import 'package:supermarket/presentation/features/accounting/cash_flow_page.dart';
import 'package:supermarket/presentation/features/accounting/chart_of_accounts_page.dart';
import 'package:supermarket/presentation/features/accounting/general_ledger_page.dart';
import 'package:supermarket/presentation/features/accounting/expenses_page.dart';
import 'package:supermarket/presentation/features/accounting/manual_journal_entry_page.dart';
import 'package:supermarket/presentation/features/accounting/reconciliation_page.dart';
import 'package:supermarket/presentation/features/accounting/shifts_page.dart';
import 'package:supermarket/presentation/features/accounting/income_statement_page.dart';
import 'package:supermarket/presentation/features/accounting/balance_sheet_page.dart';
import 'package:supermarket/presentation/features/reports/inventory_reports_screen.dart';
import 'package:supermarket/presentation/features/reports/vat_report_page.dart';
import 'package:supermarket/presentation/features/reports/audit_log_page.dart';
import 'package:supermarket/presentation/features/reports/printer_settings_page.dart';
import 'package:supermarket/presentation/features/returns/returns_page.dart';
import 'package:supermarket/presentation/features/returns/create_return_page.dart';
import 'package:supermarket/presentation/features/sync/sync_page.dart';
import 'package:supermarket/core/network/sync_service.dart';
import 'package:supermarket/presentation/features/settings/backup_page.dart';
import 'package:supermarket/presentation/features/customers/customers_page.dart';
import 'package:supermarket/presentation/features/customers/customer_statement_page.dart';
import 'package:supermarket/presentation/features/customers/customer_statement_provider.dart';
import 'package:supermarket/presentation/features/suppliers/suppliers_page.dart';
import 'package:supermarket/presentation/features/inventory/stock_transfer_page.dart';
import 'package:supermarket/presentation/features/hr/employees_page.dart';
import 'package:supermarket/presentation/features/hr/payroll_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Services & Providers Imports
import 'package:supermarket/core/services/shift_service.dart';
import 'package:supermarket/core/services/hr_service.dart';
import 'package:supermarket/core/services/stock_transfer_service.dart';
import 'package:supermarket/core/services/asset_service.dart';
import 'package:supermarket/presentation/features/accounting/shifts_provider.dart';
import 'package:supermarket/presentation/features/accounting/asset_provider.dart';
import 'package:supermarket/presentation/features/hr/hr_provider.dart';
import 'package:supermarket/presentation/features/hr/payroll_provider.dart';
import 'package:supermarket/presentation/features/inventory/stock_transfer_provider.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase with error handling
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint("Firebase initialization failed: $e");
    }

    // Initialize Dependency Injection
    di.init();

    // Seed default admin user
    final authProvider = di.sl<AuthProvider>();
    await authProvider.seedAdmin();

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
        ChangeNotifierProvider(create: (_) => di.sl<ThemeProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<AuthProvider>()),
        ChangeNotifierProvider(create: (_) => AccountingProvider(db)),
        ChangeNotifierProvider(create: (_) => ShiftProvider(ShiftService(db))),
        ChangeNotifierProvider(create: (_) => HRProvider(HRService(db))),
        ChangeNotifierProvider(create: (_) => PayrollProvider(HRService(db))),
        ChangeNotifierProvider(create: (_) => StockTransferProvider(StockTransferService(db))),
        ChangeNotifierProvider(create: (_) => AssetProvider(AssetService(db))),
        ChangeNotifierProvider(create: (_) => CustomerStatementProvider()),
        Provider<SyncService>(create: (_) => SyncService(db)),
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
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        GoRoute(
          path: '/users',
          builder: (context, state) => const StaffManagementPage(),
        ),
        GoRoute(path: '/pos', builder: (context, state) => const PosPage()),
        GoRoute(
          path: '/sales',
          builder: (context, state) => const SalesHistoryPage(),
        ),
        GoRoute(
          path: '/sales/returns',
          builder: (context, state) => const SalesReturnPage(),
        ),
        GoRoute(
          path: '/sales/returns/new',
          builder: (context, state) => const AddSalesReturnPage(),
        ),
        GoRoute(
          path: '/products',
          builder: (context, state) => const ProductsPage(),
        ),
        GoRoute(
          path: '/categories',
          builder: (context, state) => const CategoriesPage(),
        ),
        GoRoute(
          path: '/customers',
          builder: (context, state) => const CustomersPage(),
        ),
        GoRoute(
          path: '/customers/statement/:id',
          builder: (context, state) => CustomerStatementPage(
            customerId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/suppliers',
          builder: (context, state) => const SuppliersPage(),
        ),
        GoRoute(
          path: '/purchases',
          builder: (context, state) => const PurchasesPage(),
        ),
        GoRoute(
          path: '/purchases/new',
          builder: (context, state) => const AddPurchasePage(),
        ),
        GoRoute(
          path: '/purchases/returns',
          builder: (context, state) => const PurchaseReturnPage(),
        ),
        GoRoute(
          path: '/purchases/returns/new',
          builder: (context, state) => const AddPurchaseReturnPage(),
        ),
        GoRoute(
          path: '/low-stock',
          builder: (context, state) => const LowStockProductsPage(),
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
        GoRoute(path: '/sync', builder: (context, state) => const SyncPage()),
        // Reports Routes
        GoRoute(
          path: '/reports',
          builder: (context, state) => const InventoryReportsScreen(),
        ),
        GoRoute(
          path: '/reports/vat',
          builder: (context, state) => const VatReportPage(),
        ),
        GoRoute(
          path: '/reports/audit',
          builder: (context, state) => const AuditLogPage(),
        ),
        GoRoute(
          path: '/settings/printer',
          builder: (context, state) => const PrinterSettingsPage(),
        ),
        GoRoute(
          path: '/settings/backup',
          builder: (context, state) => const BackupPage(),
        ),
        // Inventory Routes
        GoRoute(
          path: '/inventory/transfer',
          builder: (context, state) => const StockTransferPage(),
        ),
        // HR Routes
        GoRoute(
          path: '/hr/employees',
          builder: (context, state) => const EmployeesPage(),
        ),
        GoRoute(
          path: '/hr/payroll',
          builder: (context, state) => const PayrollPage(),
        ),
        // Accounting Routes
        GoRoute(
          path: '/accounting/trial-balance',
          builder: (context, state) => const TrialBalancePage(),
        ),
        GoRoute(
          path: '/accounting/cash-flow',
          builder: (context, state) => const CashFlowPage(),
        ),
        GoRoute(
          path: '/accounting/coa',
          builder: (context, state) => const ChartOfAccountsPage(),
        ),
        GoRoute(
          path: '/accounting/general-ledger',
          builder: (context, state) => const GeneralLedgerPage(),
        ),
        GoRoute(
          path: '/accounting/expenses',
          builder: (context, state) => const ExpensesPage(),
        ),
        GoRoute(
          path: '/accounting/manual-entry',
          builder: (context, state) => const ManualJournalEntryPage(),
        ),
        GoRoute(
          path: '/accounting/reconciliation',
          builder: (context, state) => const ReconciliationPage(),
        ),
        GoRoute(
          path: '/accounting/shifts',
          builder: (context, state) => const ShiftsPage(),
        ),
        GoRoute(
          path: '/accounting/income-statement',
          builder: (context, state) => const IncomeStatementPage(),
        ),
        GoRoute(
          path: '/accounting/balance-sheet',
          builder: (context, state) => const BalanceSheetPage(),
        ),
      ],
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
    );
  }
}
