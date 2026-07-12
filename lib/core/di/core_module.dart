import 'package:get_it/get_it.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/products_dao.dart';
import 'package:supermarket/data/datasources/local/daos/product_units_dao.dart';
import 'package:supermarket/data/datasources/local/daos/stock_movement_dao.dart';
import 'package:supermarket/data/datasources/local/daos/audit_dao.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/core/services/app_config_service.dart';
import 'package:supermarket/core/services/app_settings_service.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:supermarket/core/services/posting_engine.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/core/services/security_service.dart';
import 'package:supermarket/core/services/permission_service.dart';
import 'package:supermarket/core/services/advanced_permission_service.dart';
import 'package:supermarket/core/services/approval_workflow_service.dart';
import 'package:supermarket/core/services/reconciliation_service.dart';
import 'package:supermarket/core/services/report_engine_service.dart';
import 'package:supermarket/core/services/dashboard_service.dart';
import 'package:supermarket/core/services/analytics_service.dart';
import 'package:supermarket/core/services/notification_service.dart';
import 'package:supermarket/core/services/thermal_printer_service.dart';
import 'package:supermarket/core/services/backup/backup_service.dart';
import 'package:supermarket/core/services/cash_management_service.dart';
import 'package:supermarket/core/services/transfer_service.dart';
import 'package:supermarket/core/services/tax_service.dart';
import 'package:supermarket/core/services/withholding_tax_service.dart';
import 'package:supermarket/core/services/bom_service.dart';
import 'package:supermarket/core/services/packaging_engine.dart';
import 'package:supermarket/core/services/pdf_service.dart';
import 'package:supermarket/data/repositories/inventory_repository_impl.dart';
import 'package:supermarket/data/repositories/item_repository_impl.dart';
import 'package:supermarket/domain/repositories/inventory_repository.dart';
import 'package:supermarket/domain/repositories/item_repository.dart';
import 'package:supermarket/domain/repositories/category_repository.dart';
import 'package:supermarket/domain/repositories/quotation_repository.dart';
import 'package:supermarket/data/repositories/category_repository_impl.dart';
import 'package:supermarket/data/repositories/quotation_repository_impl.dart';
import 'package:supermarket/domain/usecases/add_stock.dart';
import 'package:supermarket/domain/usecases/create_item.dart';
import 'package:supermarket/domain/services/approval_workflow_service.dart' as domain;
import 'package:supermarket/domain/services/fefo_service.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';
import 'package:supermarket/core/services/budget_service.dart';
import 'package:supermarket/domain/usecases/add_category.dart';
import 'package:supermarket/domain/usecases/delete_category.dart';
import 'package:supermarket/domain/usecases/get_categories.dart';
import 'package:supermarket/domain/usecases/update_category.dart';
import 'package:supermarket/domain/usecases/create_quotation.dart';

void registerCoreModule(GetIt sl) {
  final db = sl<AppDatabase>();

  // DAOs
  sl.registerLazySingleton<ProductsDao>(() => ProductsDao(db));
  sl.registerLazySingleton<ProductUnitsDao>(() => ProductUnitsDao(db));
  sl.registerLazySingleton<StockMovementDao>(() => StockMovementDao(db));
  sl.registerLazySingleton<AuditDao>(() => AuditDao(db));

  // Core services
  sl.registerLazySingleton<EventBusService>(() => EventBusService());
  sl.registerLazySingleton<AuditService>(() => AuditService(db));
  sl.registerLazySingleton<AppConfigService>(() => AppConfigService(db));
  sl.registerLazySingleton<AppSettingsService>(() => AppSettingsService(db));
  sl.registerLazySingleton<SecurityService>(() => SecurityService(db));
  sl.registerLazySingleton<PermissionService>(() => PermissionService(db));
  sl.registerLazySingleton<AdvancedPermissionService>(
    () => AdvancedPermissionService(db),
  );
  sl.registerLazySingleton<ApprovalWorkflowService>(
    () => ApprovalWorkflowService(sl<AppConfigService>()),
  );
  sl.registerLazySingleton<ReconciliationService>(
    () => ReconciliationService(db),
  );
  sl.registerLazySingleton<ReportEngineService>(
    () => ReportEngineService(db),
  );
  sl.registerLazySingleton<DashboardService>(() => DashboardService(db));
  sl.registerLazySingleton<AnalyticsService>(() => AnalyticsService(db));
  sl.registerLazySingleton<NotificationService>(() => NotificationService());
  sl.registerLazySingleton<PdfInvoiceService>(() => PdfInvoiceService());
  sl.registerLazySingleton<ThermalPrinterService>(
    () => ThermalPrinterService(),
  );
  sl.registerLazySingleton<BackupService>(() => BackupService(db));
  sl.registerLazySingleton<CashManagementService>(
    () => CashManagementService(db, sl<PostingEngine>()),
  );
  sl.registerLazySingleton<TransferService>(() => TransferService(db));
  sl.registerLazySingleton<TaxService>(() => TaxService(sl<AppSettingsService>()));
  sl.registerLazySingleton<WithholdingTaxService>(
    () => WithholdingTaxService(db),
  );
  sl.registerLazySingleton<BomService>(() => BomService(db));
  sl.registerLazySingleton<PackagingEngine>(() => PackagingEngine(db));

  // Engines
  sl.registerLazySingleton<InventoryCostingService>(
    () => InventoryCostingService(sl<StockMovementDao>(), db),
  );
  sl.registerLazySingleton<PostingEngine>(
    () => PostingEngine(db, costingService: sl<InventoryCostingService>()),
  );
  sl.registerLazySingleton<TransactionEngine>(() {
    final engine = TransactionEngine(
      db,
      sl<EventBusService>(),
      sl<PostingEngine>(),
      sl<PackagingEngine>(),
    );
    engine.setCostingService(sl<InventoryCostingService>());
    engine.setBudgetService(sl<BudgetService>());
    engine.setApprovalService(sl<ApprovalWorkflowService>());
    return engine;
  });

  // Domain
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
  sl.registerLazySingleton<AddCategory>(
    () => AddCategory(sl<CategoryRepository>()),
  );
  sl.registerLazySingleton<DeleteCategory>(
    () => DeleteCategory(sl<CategoryRepository>()),
  );
  sl.registerLazySingleton<GetCategories>(
    () => GetCategories(sl<CategoryRepository>()),
  );
  sl.registerLazySingleton<UpdateCategory>(
    () => UpdateCategory(sl<CategoryRepository>()),
  );
  sl.registerLazySingleton<CreateQuotation>(
    () => CreateQuotation(sl<QuotationRepository>()),
  );
  sl.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(appDatabase: db),
  );
  sl.registerLazySingleton<QuotationRepository>(
    () => QuotationRepositoryImpl(database: db),
  );
  sl.registerLazySingleton<domain.ApprovalWorkflowService>(
    () => domain.ApprovalWorkflowService(database: db),
  );
  sl.registerLazySingleton<FefoService>(
    () => FefoService(repository: sl<InventoryRepository>()),
  );
}
