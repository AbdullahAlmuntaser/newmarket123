import 'package:get_it/get_it.dart';
import 'package:supermarket/core/services/inventory_service.dart';
import 'package:supermarket/core/services/inventory_report_service.dart';
import 'package:supermarket/core/services/stock_operation_service.dart';
import 'package:supermarket/core/services/inventory_reservation_service.dart';
import 'package:supermarket/core/services/inventory_audit_service.dart';
import 'package:supermarket/core/services/stock_transfer_service.dart';
import 'package:supermarket/core/services/reorder_service.dart';
import 'package:supermarket/core/services/serial_number_service.dart';
import 'package:supermarket/core/services/barcode_generation_service.dart';
import 'package:supermarket/core/services/barcode_scanner_service.dart';
import 'package:supermarket/core/services/product_image_service.dart';
import 'package:supermarket/core/services/unit_conversion_service.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/core/services/app_config_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/products_dao.dart';
import 'package:supermarket/data/datasources/local/daos/product_units_dao.dart';

void registerInventoryModule(GetIt sl) {
  final db = sl<AppDatabase>();

  // NOTE: InventoryCostingService is registered in core_module.dart
  // because PostingEngine and TransactionEngine depend on it.
  sl.registerLazySingleton<InventoryReportService>(
    () => InventoryReportService(db),
  );
  sl.registerLazySingleton<StockOperationService>(
    () => StockOperationService(db, sl<AuditService>(), sl<AppConfigService>()),
  );
  sl.registerLazySingleton<InventoryService>(
    () => InventoryService(
      sl<InventoryReportService>(),
      sl<StockOperationService>(),
    ),
  );
  sl.registerLazySingleton<InventoryReservationService>(
    () => InventoryReservationService(db),
  );
  sl.registerLazySingleton<InventoryAuditService>(
    () => InventoryAuditService(db),
  );
  sl.registerLazySingleton<StockTransferService>(
    () => StockTransferService(db),
  );
  sl.registerLazySingleton<ReorderService>(() => ReorderService(db));
  sl.registerLazySingleton<SerialNumberService>(
    () => SerialNumberService(db),
  );
  sl.registerLazySingleton<BarcodeGenerationService>(
    () => BarcodeGenerationService(),
  );
  sl.registerLazySingleton<BarcodeScannerService>(
    () => BarcodeScannerService(),
  );
  sl.registerLazySingleton<ProductImageService>(
    () => ProductImageService(),
  );
  sl.registerLazySingleton<UnitConversionService>(
    () => UnitConversionService(
      productsDao: sl<ProductsDao>(),
      productUnitsDao: sl<ProductUnitsDao>(),
    ),
  );
}
