import 'package:get_it/get_it.dart';
import 'package:supermarket/core/services/purchase_service.dart';
import 'package:supermarket/core/services/purchase_converter.dart';
import 'package:supermarket/core/services/grn_service.dart';
import 'package:supermarket/core/services/supplier_analytics_service.dart';
import 'package:supermarket/core/services/aging_service.dart';
import 'package:supermarket/core/services/posting_engine.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';
import 'package:supermarket/core/services/app_config_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

void registerPurchaseModule(GetIt sl) {
  final db = sl<AppDatabase>();

  sl.registerLazySingleton<PurchaseService>(
    () => PurchaseService(db, sl<PostingEngine>(),
        sl<InventoryCostingService>(), sl<AppConfigService>()),
  );
  sl.registerLazySingleton<PurchaseConverter>(
    () => PurchaseConverter(db),
  );
  sl.registerLazySingleton<GrnService>(() => GrnService(db));
  sl.registerLazySingleton<SupplierAnalyticsService>(
    () => SupplierAnalyticsService(db),
  );
  sl.registerLazySingleton<AgingService>(() => AgingService(db));
}
