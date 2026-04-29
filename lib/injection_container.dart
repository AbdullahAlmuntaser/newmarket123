import 'package:get_it/get_it.dart';
import 'core/auth/auth_provider.dart';
import 'core/services/permission_service.dart';
import 'core/services/inventory_service.dart';
import 'core/services/accounting_service.dart';
import 'core/services/event_bus_service.dart';
import 'core/services/financial_control_service.dart';
import 'core/services/grn_service.dart';
import 'core/utils/drive_backup_service.dart';
import 'core/theme/theme_provider.dart';
import 'data/datasources/local/app_database.dart';
import 'data/datasources/local/daos/products_dao.dart';
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
import 'core/services/statement_service.dart';
import 'core/services/report_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  final db = AppDatabase();
  sl.registerLazySingleton<AppDatabase>(() => db);
sl.registerLazySingleton<AuditDao>(() => AuditDao(db));
sl.registerLazySingleton<StockMovementDao>(() => StockMovementDao(db));
sl.registerLazySingleton<ProductsDao>(() => ProductsDao(db));

sl.registerLazySingleton<AccountingService>(
  () => AccountingService(db, sl<EventBusService>()),
);
sl.registerLazySingleton<PostingEngine>(() => PostingEngine(db, costingService: sl<InventoryCostingService>()));
  sl.registerLazySingleton<InventoryCostingService>(
    () => InventoryCostingService(sl<StockMovementDao>(), sl<AppDatabase>()),
  );
sl.registerLazySingleton<PermissionService>(() => PermissionService(db));
sl.registerLazySingleton<AuditService>(() => AuditService(db));
sl.registerLazySingleton<InventoryService>(() => InventoryService(db));
sl.registerLazySingleton<EventBusService>(() => EventBusService());
sl.registerLazySingleton<PurchaseService>(
  () =>
      PurchaseService(db, sl<PostingEngine>(), sl<InventoryCostingService>()),
);
sl.registerLazySingleton<SalesService>(
  () => SalesService(sl<PostingEngine>(), sl<InventoryService>()),
);
sl.registerLazySingleton<StatementService>(
  () => StatementService(sl<PostingEngine>()),
);
sl.registerLazySingleton<ReportService>(() => ReportService(sl<PostingEngine>()));

sl.registerLazySingleton<AuthProvider>(() => AuthProvider(
  sl<AppDatabase>(),
  sl<PermissionService>(),
));

sl.registerLazySingleton<ItemRepository>(() => ItemRepositoryImpl(sl<ProductsDao>()));sl.registerLazySingleton<InventoryRepository>(() => InventoryRepositoryImpl(
  sl<StockMovementDao>(),
  sl<ProductsDao>(),
));

  sl.registerLazySingleton<CreateItemUseCase>(
    () => CreateItemUseCase(sl<ItemRepository>()),
  );
  sl.registerLazySingleton<AddStockUseCase>(
    () => AddStockUseCase(sl<InventoryRepository>()),
  );
  sl.registerLazySingleton<ThemeProvider>(() => ThemeProvider());
  sl.registerLazySingleton(() => BomService(db, sl<AccountingService>()));
  sl.registerLazySingleton<GrnService>(() => GrnService(db));
  sl.registerLazySingleton<DriveBackupService>(() => DriveBackupService(db));
  sl.registerLazySingleton<FinancialControlService>(
    () => FinancialControlService(db, costingService: sl<InventoryCostingService>()),
  );
}
