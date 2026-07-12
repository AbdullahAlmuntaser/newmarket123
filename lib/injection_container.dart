import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:get_it/get_it.dart';
import 'core/auth/auth_provider.dart';
import 'core/services/permission_service.dart';
import 'core/services/app_config_service.dart';
import 'core/services/approval_workflow_service.dart';
import 'core/services/loyalty_service.dart';
import 'core/services/accounting_service.dart';
import 'core/services/event_bus_service.dart';
import 'core/services/financial_control_service.dart';
import 'core/services/security_service.dart';
import 'core/utils/drive_backup_service.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/locale_provider.dart';
import 'core/services/packaging_engine.dart';
import 'data/datasources/local/app_database.dart';
import 'core/services/inventory_costing_service.dart';
import 'core/services/purchase_service.dart';

import 'core/services/pricing_service.dart';
import 'core/services/transaction_engine.dart';
import 'core/services/communication_service.dart';
import 'core/services/production_service.dart';
import 'core/services/hr_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/dashboard_service.dart';
import 'core/services/shift_service.dart';
import 'core/services/stock_transfer_service.dart';
import 'core/services/asset_service.dart';
import 'core/services/return_service.dart';
import 'core/services/quick_customer_service.dart';
import 'core/services/financial_closing_service.dart';
import 'core/services/system_auditor.dart';
import 'core/services/report_engine_service.dart';
import 'core/services/accounting_period_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/audit_log_service.dart';
import 'core/services/erp_data_service.dart';
import 'core/services/fixed_assets_service.dart';
import 'core/services/inventory_audit_service.dart';
import 'core/services/invoice_service.dart';
import 'core/services/profitability_service.dart';

import 'core/services/pdf_service.dart';
import 'core/services/budget_service.dart';
import 'core/services/cash_management_service.dart';
import 'core/services/transfer_service.dart';
import 'core/services/unified_statement_service.dart';
import 'core/services/payroll_service.dart';
import 'core/services/currency_conversion_service.dart';
import 'core/services/zakat_service.dart';
import 'core/services/eosb_service.dart';
import 'core/services/inventory_reservation_service.dart';
import 'core/services/multi_level_approval_service.dart';
import 'core/services/leave_management_service.dart';
import 'core/services/attendance_service.dart';
import 'core/services/withholding_tax_service.dart';
import 'core/services/serial_number_service.dart';
import 'core/services/credit_note_service.dart';
import 'core/services/sales_commission_service.dart';
import 'core/services/proforma_service.dart';
import 'core/di/core_module.dart';
import 'core/di/accounting_module.dart';
import 'core/di/inventory_module.dart';
import 'core/di/purchase_module.dart';
import 'core/di/sales_module.dart';
import 'core/di/hr_module.dart';
import 'presentation/features/accounting/accounting_provider.dart';
import 'presentation/features/purchases/purchase_provider.dart';
import 'presentation/features/accounting/shifts_provider.dart';
import 'presentation/features/hr/hr_provider.dart';
import 'presentation/features/hr/payroll_provider.dart';
import 'presentation/features/inventory/stock_transfer_provider.dart';
import 'presentation/features/accounting/asset_provider.dart';
import 'presentation/features/customers/customer_statement_provider.dart';
import 'presentation/features/dashboard/dashboard_provider.dart';
import 'presentation/features/home/providers/command_center_provider.dart';
import 'presentation/features/pos/bloc/pos_bloc.dart';
import 'core/services/fast_access_service.dart';
import 'core/utils/cache_service.dart';
import 'core/utils/paginated_query.dart';
import 'presentation/features/products/products_provider.dart';
import 'presentation/features/accounting/zakat_provider.dart';
import 'presentation/features/hr/eosb_provider.dart';
import 'presentation/features/sales/proforma_provider.dart';
import 'presentation/features/sales/credit_note_provider.dart';
import 'presentation/features/sales/commission_provider.dart';
import 'presentation/features/accounting/wht_provider.dart';
import 'presentation/features/hr/attendance_provider.dart';
import 'presentation/features/hr/leave_provider.dart';
import 'presentation/features/inventory/serial_number_provider.dart';

final sl = GetIt.instance;
AppDatabase? _database;

Future<void> initDatabase() async {
  debugPrint("DI: ==== Opening Database ====");
  try {
    if (sl.isRegistered<AppDatabase>()) {
      _database = sl<AppDatabase>();
      debugPrint("DI: Database already registered");
      return;
    }

    final key = await SecurityService.getDatabaseKey();
    AppDatabase.encryptionKey = key;
    debugPrint("DI: Encryption key is set (${key.length} chars)");

    _database = AppDatabase();
    sl.registerLazySingleton<AppDatabase>(() => _database!);
    debugPrint("DI: Database opened successfully");
  } catch (e, stack) {
    debugPrint("DI: Database opening error: $e");
    debugPrintStack(stackTrace: stack);

    final err = e.toString();
    if (err.contains('NO_SQLCIPHER')) {
      debugPrint(
          "DI: CRITICAL - SQLCipher library not available. "
          "Database encryption is required but the native library is missing. "
          "Ensure sqlcipher_flutter_libs is properly included.");
    } else if (err.contains('CRITICAL')) {
      debugPrint(
          "DI: CRITICAL - Encryption key initialization failed. "
          "The app cannot safely open the encrypted database.");
    } else if (err.contains('code 26') ||
        err.contains('file is not a database') ||
        err.contains('DATABASE_ENCRYPTION_ERROR') ||
        err.contains('SqliteException')) {
      debugPrint(
          "DI: Database encryption/decryption error. "
          "The database file is preserved for debugging. "
          "Error: $e");
    }

    rethrow;
  }
}

Future<void> initServices() async {
  debugPrint("DI: ==== Initializing Services ====");
  try {
    if (sl.isRegistered<EventBusService>()) {
      debugPrint("DI: Services already registered");
      return;
    }

    registerCoreModule(sl);
    registerAccountingModule(sl);
    registerInventoryModule(sl);
    registerPurchaseModule(sl);
    registerSalesModule(sl);
    registerHRModule(sl);

    final db = sl<AppDatabase>();

    debugPrint("DI: Registering services not in modules...");
    // NOTE: UnitConversionService is registered in inventory_module.dart
    // NOTE: AutoBreakService is registered in hr_module.dart
    // NOTE: LoyaltyService is registered in sales_module.dart
    sl.registerLazySingleton<DriveBackupService>(() => DriveBackupService(db));
    sl.registerLazySingleton<AssetService>(() => AssetService(db));
    sl.registerLazySingleton<CommunicationService>(
        () => CommunicationService());
    sl.registerLazySingleton<ProductionService>(() => ProductionService(db));
    sl.registerLazySingleton<SystemAuditor>(() => SystemAuditor(db));
    sl.registerLazySingleton<ErpDataService>(
      () => ErpDataService(db, sl<InventoryCostingService>()),
    );
    sl.registerLazySingleton<ProfitabilityService>(
      () => ProfitabilityService(db),
    );
    // NOTE: PdfInvoiceService is registered in core_module.dart
    sl.registerLazySingleton<FastAccessService>(() => FastAccessService());
    sl.registerLazySingleton<CacheService>(() => CacheService());
    sl.registerLazySingleton<PaginatedQuery>(
        () => PaginatedQuery(sl<AppDatabase>()));
    sl.registerLazySingleton<MultiLevelApprovalService>(
      () => MultiLevelApprovalService(sl<AppConfigService>()),
    );
    // NOTE: EndOfServiceBenefitService is registered in hr_module.dart
    sl.registerLazySingleton<AuditLogService>(
      () => AuditLogService(db),
    );

    // Register missing ChangeNotifier providers
    sl.registerLazySingleton<CreditNoteProvider>(
      () => CreditNoteProvider(sl<CreditNoteService>()),
    );
    sl.registerLazySingleton<WhtProvider>(
      () => WhtProvider(sl<WithholdingTaxService>()),
    );
    sl.registerLazySingleton<CommissionProvider>(
      () => CommissionProvider(sl<SalesCommissionService>(), db),
    );
    sl.registerLazySingleton<AttendanceProvider>(
      () => AttendanceProvider(sl<AttendanceService>()),
    );
    sl.registerLazySingleton<LeaveProvider>(
      () => LeaveProvider(sl<LeaveManagementService>()),
    );
    sl.registerLazySingleton<SerialNumberProvider>(
      () => SerialNumberProvider(sl<SerialNumberService>(), db),
    );

    debugPrint("DI: Registering providers...");
    sl.registerLazySingleton<AuthProvider>(
      () => AuthProvider(db, sl<PermissionService>()),
    );
    sl.registerLazySingleton<ThemeProvider>(() => ThemeProvider());
    sl.registerLazySingleton<LocaleProvider>(
      () => LocaleProvider(sl<AppConfigService>()),
    );
    sl.registerLazySingleton<CommandCenterProvider>(() => CommandCenterProvider(
          db,
          sl<FastAccessService>(),
        ));
    sl.registerFactory<ProductsProvider>(() => ProductsProvider(db));
    sl.registerFactory<AccountingProvider>(
        () => AccountingProvider(db, sl<AccountingService>()));
    sl.registerFactory<PurchaseProvider>(
      () => PurchaseProvider(db, sl<PurchaseService>()),
    );
    sl.registerFactory<ShiftProvider>(
      () => ShiftProvider(sl<ShiftService>()),
    );
    sl.registerFactory<HRProvider>(() => HRProvider(sl<HRService>()));
    sl.registerFactory<PayrollProvider>(
      () => PayrollProvider(sl<HRService>(), sl<PayrollService>()),
    );
    sl.registerFactory<StockTransferProvider>(
      () => StockTransferProvider(sl<StockTransferService>()),
    );
    sl.registerFactory<AssetProvider>(
      () => AssetProvider(sl<AssetService>()),
    );
    sl.registerFactory<CustomerStatementProvider>(
      () => CustomerStatementProvider(),
    );
    sl.registerFactory<DashboardProvider>(() => DashboardProvider(db));
    sl.registerFactory<PosBloc>(
      () => PosBloc(db, sl<PricingService>(), sl<TransactionEngine>(),
          sl<PackagingEngine>(), loyaltyService: sl<LoyaltyService>()),
    );
    debugPrint("DI: Providers registered");

    debugPrint("DI: ==== Services Initialization Complete ====");
  } catch (e, stack) {
    debugPrint("DI: Services initialization error: $e");
    debugPrintStack(stackTrace: stack);
    rethrow;
  }
}

List<SingleChildWidget> buildAppProviders() {
  return [
    Provider<AppDatabase>.value(value: sl<AppDatabase>()),
    Provider<AccountingService>.value(value: sl<AccountingService>()),
    Provider<DashboardService>.value(value: sl<DashboardService>()),
    Provider<ApprovalWorkflowService>.value(
      value: sl<ApprovalWorkflowService>(),
    ),
    Provider<LoyaltyService>.value(value: sl<LoyaltyService>()),
    ChangeNotifierProvider<NotificationService>.value(
      value: sl<NotificationService>(),
    ),
    ChangeNotifierProvider<ThemeProvider>.value(value: sl<ThemeProvider>()),
    ChangeNotifierProvider<LocaleProvider>.value(value: sl<LocaleProvider>()),
    ChangeNotifierProvider<AuthProvider>.value(value: sl<AuthProvider>()),
    ChangeNotifierProvider<FastAccessService>.value(
        value: sl<FastAccessService>()),
    ChangeNotifierProvider<AccountingProvider>(
      create: (_) => sl<AccountingProvider>(),
    ),
    ChangeNotifierProvider<ProductsProvider>(
      create: (_) => sl<ProductsProvider>(),
    ),
    ChangeNotifierProvider<PurchaseProvider>(
      create: (_) => sl<PurchaseProvider>(),
    ),
    ChangeNotifierProvider<ShiftProvider>(
      create: (_) => sl<ShiftProvider>(),
    ),
    ChangeNotifierProvider<HRProvider>(
      create: (_) => sl<HRProvider>(),
    ),
    ChangeNotifierProvider<PayrollProvider>(
      create: (_) => sl<PayrollProvider>(),
    ),
    ChangeNotifierProvider<StockTransferProvider>(
      create: (_) => sl<StockTransferProvider>(),
    ),
    ChangeNotifierProvider<AssetProvider>(
      create: (_) => sl<AssetProvider>(),
    ),

    ChangeNotifierProvider<CustomerStatementProvider>(
      create: (_) => sl<CustomerStatementProvider>(),
    ),
    ChangeNotifierProvider<DashboardProvider>(
      create: (_) => sl<DashboardProvider>(),
    ),
    ChangeNotifierProvider<CommandCenterProvider>(
      create: (_) => sl<CommandCenterProvider>(),
    ),
    Provider<ReturnService>.value(value: sl<ReturnService>()),
    Provider<QuickCustomerService>.value(value: sl<QuickCustomerService>()),
    Provider<FinancialClosingService>.value(
      value: sl<FinancialClosingService>(),
    ),
    Provider<SystemAuditor>.value(value: sl<SystemAuditor>()),
    Provider<ReportEngineService>.value(value: sl<ReportEngineService>()),
    // Provide additional services that were not previously provided
    Provider<AccountingPeriodService>.value(
      value: sl<AccountingPeriodService>(),
    ),
    Provider<AnalyticsService>.value(value: sl<AnalyticsService>()),
    Provider<AuditLogService>.value(value: sl<AuditLogService>()),
    Provider<ErpDataService>.value(value: sl<ErpDataService>()),
    Provider<FixedAssetsService>.value(value: sl<FixedAssetsService>()),
    Provider<InventoryAuditService>.value(value: sl<InventoryAuditService>()),
    Provider<InvoiceService>.value(value: sl<InvoiceService>()),
    Provider<ProfitabilityService>.value(value: sl<ProfitabilityService>()),
    Provider<PdfInvoiceService>.value(value: sl<PdfInvoiceService>()),
    // Add missing providers for services that were registered but not provided
    Provider<FinancialControlService>.value(
        value: sl<FinancialControlService>()),
    // Provide BudgetService and PayrollService
    Provider<BudgetService>.value(value: sl<BudgetService>()),
    Provider<PayrollService>.value(value: sl<PayrollService>()),
    Provider<PackagingEngine>.value(value: sl<PackagingEngine>()),
    Provider<CurrencyConversionService>.value(
        value: sl<CurrencyConversionService>()),
    Provider<LeaveManagementService>.value(
        value: sl<LeaveManagementService>()),
    Provider<AttendanceService>.value(value: sl<AttendanceService>()),
    Provider<WithholdingTaxService>.value(value: sl<WithholdingTaxService>()),
    Provider<SerialNumberService>.value(value: sl<SerialNumberService>()),
    Provider<CreditNoteService>.value(value: sl<CreditNoteService>()),
    Provider<SalesCommissionService>.value(
        value: sl<SalesCommissionService>()),
    Provider<ZakatService>.value(value: sl<ZakatService>()),
    Provider<EndOfServiceBenefitService>.value(
        value: sl<EndOfServiceBenefitService>()),
    Provider<InventoryReservationService>.value(
        value: sl<InventoryReservationService>()),
    Provider<MultiLevelApprovalService>.value(
      value: sl<MultiLevelApprovalService>()),
    ChangeNotifierProvider<ZakatProvider>(
      create: (_) => ZakatProvider(sl<ZakatService>()),
    ),
    ChangeNotifierProvider<EOSBProvider>(
      create: (_) => EOSBProvider(sl<EndOfServiceBenefitService>(), sl<AppDatabase>()),
    ),
    ChangeNotifierProvider<ProformaProvider>(
      create: (_) => ProformaProvider(sl<ProformaService>()),
    ),
    // Missing service providers (Fix 4)
    Provider<TransferService>.value(value: sl<TransferService>()),
    Provider<CashManagementService>.value(value: sl<CashManagementService>()),
    Provider<EventBusService>.value(value: sl<EventBusService>()),
    Provider<HRService>.value(value: sl<HRService>()),
    Provider<ProductionService>.value(value: sl<ProductionService>()),
    Provider<UnifiedStatementService>.value(value: sl<UnifiedStatementService>()),
    // Missing ChangeNotifier providers (Fix 5)
    ChangeNotifierProvider<CreditNoteProvider>(
      create: (_) => sl<CreditNoteProvider>(),
    ),
    ChangeNotifierProvider<WhtProvider>(
      create: (_) => sl<WhtProvider>(),
    ),
    ChangeNotifierProvider<CommissionProvider>(
      create: (_) => sl<CommissionProvider>(),
    ),
    ChangeNotifierProvider<AttendanceProvider>(
      create: (_) => sl<AttendanceProvider>(),
    ),
    ChangeNotifierProvider<LeaveProvider>(
      create: (_) => sl<LeaveProvider>(),
    ),
    ChangeNotifierProvider<SerialNumberProvider>(
      create: (_) => sl<SerialNumberProvider>(),
    ),
  ];
}

Future<void> init() async {
  await initDatabase();
  await initServices();
}
