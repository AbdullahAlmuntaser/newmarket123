import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:get_it/get_it.dart';
import 'core/auth/auth_provider.dart';
import 'core/services/permission_service.dart';
import 'core/services/app_settings_service.dart';
import 'core/services/app_config_service.dart';
import 'core/services/approval_workflow_service.dart';
import 'core/services/loyalty_service.dart';
import 'core/services/inventory_service.dart';
import 'core/services/accounting_service.dart';
import 'core/services/event_bus_service.dart';
import 'core/services/financial_control_service.dart';
import 'core/services/grn_service.dart';
import 'core/utils/drive_backup_service.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/locale_provider.dart';
import 'core/services/unit_conversion_service.dart';
import 'data/datasources/local/app_database.dart';
import 'data/datasources/local/daos/products_dao.dart';
import 'data/datasources/local/daos/product_units_dao.dart';
import 'core/services/posting_engine.dart';
import 'core/services/inventory_costing_service.dart';
import 'data/datasources/local/daos/stock_movement_dao.dart';
import 'data/datasources/local/daos/audit_dao.dart';
import 'core/services/audit_service.dart';
import 'data/repositories/inventory_repository_impl.dart';
import 'data/repositories/item_repository_impl.dart';
import 'domain/repositories/inventory_repository.dart';
import 'domain/repositories/item_repository.dart';
import 'domain/usecases/create_item.dart';
import 'domain/usecases/add_stock.dart';
import 'core/services/bom_service.dart';
import 'core/services/sales_service.dart';
import 'core/services/purchase_service.dart';
import 'core/services/reorder_service.dart';
import 'core/services/supplier_analytics_service.dart';
import 'core/services/statement_service.dart';
import 'core/services/report_service.dart';
import 'core/services/pricing_service.dart';
import 'core/services/transaction_engine.dart';
import 'core/services/communication_service.dart';
import 'core/services/cash_management_service.dart';
import 'core/services/transfer_service.dart';
import 'core/services/statement_printing_service.dart';
import 'core/services/unified_statement_service.dart';
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
import 'core/services/reporting_service.dart';
import 'core/services/pdf_service.dart';
import 'presentation/features/accounting/accounting_provider.dart';
import 'presentation/features/purchases/purchase_provider.dart';
import 'presentation/features/accounting/shifts_provider.dart';
import 'presentation/features/hr/hr_provider.dart';
import 'presentation/features/hr/payroll_provider.dart';
import 'presentation/features/inventory/stock_transfer_provider.dart';
import 'presentation/features/accounting/asset_provider.dart';
import 'presentation/features/customers/customer_statement_provider.dart';
import 'presentation/features/dashboard/dashboard_provider.dart';
import 'presentation/features/pos/bloc/pos_bloc.dart';
import 'presentation/features/products/products_provider.dart';

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

    _database = AppDatabase();
    sl.registerLazySingleton<AppDatabase>(() => _database!);
    debugPrint("DI: Database opened successfully");
  } catch (e, stack) {
    debugPrint("DI: Database opening error: $e");
    debugPrintStack(stackTrace: stack);
    rethrow;
  }
}

Future<void> initServices() async {
  debugPrint("DI: ==== Initializing Services ====");
  try {
    final db = sl<AppDatabase>();

    if (sl.isRegistered<EventBusService>()) {
      debugPrint("DI: Services already registered");
      return;
    }

    debugPrint("DI: Registering DAOs...");
    sl.registerLazySingleton<AuditDao>(() => AuditDao(db));
    sl.registerLazySingleton<StockMovementDao>(() => StockMovementDao(db));
    sl.registerLazySingleton<ProductsDao>(() => ProductsDao(db));
    sl.registerLazySingleton<ProductUnitsDao>(() => ProductUnitsDao(db));

    debugPrint("DI: Registering UnitConversionService...");
    sl.registerLazySingleton<UnitConversionService>(
      () => UnitConversionService(
        productsDao: sl<ProductsDao>(),
        productUnitsDao: sl<ProductUnitsDao>(),
      ),
    );
    debugPrint("DI: DAOs registered");

    debugPrint("DI: Registering core services...");
    sl.registerLazySingleton<EventBusService>(() => EventBusService());
    sl.registerLazySingleton<InventoryCostingService>(
      () => InventoryCostingService(sl<StockMovementDao>(), sl<AppDatabase>()),
    );
    sl.registerLazySingleton<PostingEngine>(
      () => PostingEngine(db, costingService: sl<InventoryCostingService>()),
    );
    sl.registerLazySingleton<AccountingService>(
      () => AccountingService(db, sl<EventBusService>()),
    );
    sl.registerLazySingleton<PermissionService>(() => PermissionService(db));
    sl.registerLazySingleton<AuditService>(() => AuditService(db));
    sl.registerLazySingleton<AppConfigService>(() => AppConfigService(db));
    sl.registerLazySingleton<AppSettingsService>(() => AppSettingsService(db));
    sl.registerLazySingleton<ApprovalWorkflowService>(
      () => ApprovalWorkflowService(sl<AppConfigService>()),
    );
    sl.registerLazySingleton<LoyaltyService>(
      () => LoyaltyService(sl<AppConfigService>()),
    );
    sl.registerLazySingleton<InventoryService>(
      () => InventoryService(
        db,
        sl<AuditService>(),
        sl<AppConfigService>(),
      ),
    );
    debugPrint("DI: Core services registered");

    debugPrint("DI: Registering business services...");
    sl.registerLazySingleton<PurchaseService>(
      () => PurchaseService(db, sl<PostingEngine>(),
          sl<InventoryCostingService>(), sl<AppConfigService>()),
    );
    sl.registerLazySingleton<SalesService>(
      () => SalesService(
          sl<AppDatabase>(),
          sl<PostingEngine>(),
          sl<InventoryService>(),
          sl<AppSettingsService>(),
          sl<PermissionService>()),
    );
    sl.registerLazySingleton<StatementService>(
      () => StatementService(sl<PostingEngine>()),
    );
    sl.registerLazySingleton<ReportService>(
      () => ReportService(sl<PostingEngine>()),
    );
    debugPrint("DI: Business services registered");

    debugPrint("DI: Registering repositories...");
    sl.registerLazySingleton<AuthProvider>(
      () => AuthProvider(sl<AppDatabase>(), sl<PermissionService>()),
    );
    sl.registerLazySingleton<ItemRepository>(
      () => ItemRepositoryImpl(sl<ProductsDao>()),
    );
    sl.registerLazySingleton<InventoryRepository>(
      () => InventoryRepositoryImpl(sl<StockMovementDao>(), sl<ProductsDao>()),
    );
    sl.registerLazySingleton<CreateItemUseCase>(
      () => CreateItemUseCase(sl<ItemRepository>()),
    );
    sl.registerLazySingleton<AddStockUseCase>(
      () => AddStockUseCase(sl<InventoryRepository>()),
    );
    debugPrint("DI: Repositories registered");

    debugPrint("DI: Registering additional services...");
    sl.registerLazySingleton<ThemeProvider>(() => ThemeProvider());
    sl.registerLazySingleton<LocaleProvider>(
      () => LocaleProvider(sl<AppConfigService>()),
    );
    sl.registerLazySingleton(() => BomService(db, sl<AccountingService>()));
    sl.registerLazySingleton<GrnService>(() => GrnService(db));
    sl.registerLazySingleton<ReorderService>(() => ReorderService(db));
    sl.registerLazySingleton<SupplierAnalyticsService>(
        () => SupplierAnalyticsService(db));
    sl.registerLazySingleton<DriveBackupService>(() => DriveBackupService(db));
    sl.registerLazySingleton<FinancialControlService>(
      () => FinancialControlService(
        db,
        costingService: sl<InventoryCostingService>(),
      ),
    );
    sl.registerLazySingleton<PricingService>(() => PricingService(db));
    sl.registerLazySingleton<TransactionEngine>(() {
      final engine = TransactionEngine(db, sl<EventBusService>());
      engine.setCostingService(sl<InventoryCostingService>());
      return engine;
    });
    sl.registerLazySingleton<CashManagementService>(
        () => CashManagementService(db, sl<EventBusService>()));
    sl.registerLazySingleton<TransferService>(() => TransferService(db));
    sl.registerLazySingleton<StatementPrintingService>(
        () => StatementPrintingService(db));
    sl.registerLazySingleton<UnifiedStatementService>(
        () => UnifiedStatementService(db));
    sl.registerLazySingleton<ProductionService>(() => ProductionService(db));
    sl.registerLazySingleton<HRService>(() => HRService(db));
    sl.registerLazySingleton<NotificationService>(() => NotificationService());
    sl.registerLazySingleton<DashboardService>(() => DashboardService(db));
    sl.registerLazySingleton<ShiftService>(() => ShiftService(db));
    sl.registerLazySingleton<StockTransferService>(
      () => StockTransferService(db),
    );
    sl.registerLazySingleton<AssetService>(() => AssetService(db));
    sl.registerLazySingleton<CommunicationService>(
        () => CommunicationService());
    sl.registerLazySingleton<ReturnService>(() => ReturnService(db));
    sl.registerLazySingleton<QuickCustomerService>(
      () => QuickCustomerService(db),
    );
    sl.registerLazySingleton<FinancialClosingService>(
      () => FinancialClosingService(db),
    );
    sl.registerLazySingleton<SystemAuditor>(() => SystemAuditor(db));
    sl.registerLazySingleton<ReportEngineService>(
      () => ReportEngineService(db),
    );
    
    // Register additional services that were not previously registered
    debugPrint("DI: Registering additional unregistered services...");
    sl.registerLazySingleton<AccountingPeriodService>(
      () => AccountingPeriodService(db),
    );
    sl.registerLazySingleton<AnalyticsService>(
      () => AnalyticsService(db),
    );
    sl.registerLazySingleton<AuditLogService>(
      () => AuditLogService(db),
    );
    sl.registerLazySingleton<ErpDataService>(
      () => ErpDataService(db, sl<InventoryCostingService>()),
    );
    sl.registerLazySingleton<FixedAssetsService>(
      () => FixedAssetsService(db),
    );
    sl.registerLazySingleton<InventoryAuditService>(
      () => InventoryAuditService(db),
    );
    sl.registerLazySingleton<InvoiceService>(
      () => InvoiceService(db),
    );
    sl.registerLazySingleton<ProfitabilityService>(
      () => ProfitabilityService(db),
    );
    sl.registerLazySingleton<ReportingService>(
      () => ReportingService(db),
    );
    sl.registerLazySingleton<PdfInvoiceService>(
      () => PdfInvoiceService(),
    );
    debugPrint("DI: Additional services registered");
    
    debugPrint("DI: Registering providers...");
    sl.registerFactory<ProductsProvider>(() => ProductsProvider(db));
    sl.registerFactory<AccountingProvider>(() => AccountingProvider(db));
    sl.registerFactory<PurchaseProvider>(
      () => PurchaseProvider(db, sl<PurchaseService>()),
    );
    sl.registerFactory<ShiftProvider>(
      () => ShiftProvider(sl<ShiftService>()),
    );
    sl.registerFactory<HRProvider>(() => HRProvider(sl<HRService>()));
    sl.registerFactory<PayrollProvider>(() => PayrollProvider(sl<HRService>()));
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
      () => PosBloc(db, sl<PricingService>(), sl<TransactionEngine>()),
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
    Provider<ReportingService>.value(value: sl<ReportingService>()),
    Provider<PdfInvoiceService>.value(value: sl<PdfInvoiceService>()),
    // Add missing providers for services that were registered but not provided
    Provider<FinancialControlService>.value(value: sl<FinancialControlService>()),
    Provider<ReportService>.value(value: sl<ReportService>()),
  ];
}

Future<void> init() async {
  await initDatabase();
  await initServices();
}
