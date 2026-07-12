import 'package:supermarket/core/services/inventory_report_service.dart';
import 'package:supermarket/core/services/stock_operation_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/models/inventory/inventory_models.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/core/services/app_config_service.dart';

class InventoryService {
  final InventoryReportService reports;
  final StockOperationService operations;

  InventoryService(this.reports, this.operations);

  InventoryService.fromDb(AppDatabase db, AuditService audit, AppConfigService config)
      : reports = InventoryReportService(db),
        operations = StockOperationService(db, audit, config);

  Stream<List<InventoryTransactionReport>> watchInventoryTransactions({
    String? productId,
    String? warehouseId,
    int limit = 100,
  }) =>
      reports.watchInventoryTransactions(
          productId: productId, warehouseId: warehouseId, limit: limit);

  Stream<List<BatchReport>> watchProductBatches({
    String? productId,
    String? warehouseId,
  }) =>
      reports.watchProductBatches(
          productId: productId, warehouseId: warehouseId);

  Future<double> getTotalInventoryValue() =>
      reports.getTotalInventoryValue();

  Stream<List<Product>> watchLowStockProducts() =>
      reports.watchLowStockProducts();

  Stream<List<BatchReport>> watchExpiringSoonBatches({int days = 30}) =>
      reports.watchExpiringSoonBatches(days: days);

  Future<void> performInventoryAudit({
    required InventoryAuditsCompanion auditCompanion,
    required List<InventoryAuditItemsCompanion> items,
    String? userId,
  }) =>
      operations.performInventoryAudit(
          auditCompanion: auditCompanion,
          items: items,
          userId: userId);

  Future<void> deductStock({
    required String itemId,
    required Decimal quantity,
    required String warehouseId,
    String? referenceId,
    String? userId,
  }) =>
      operations.deductStock(
          itemId: itemId,
          quantity: quantity,
          warehouseId: warehouseId,
          referenceId: referenceId,
          userId: userId);

  Future<void> transferStock({
    required String fromWarehouseId,
    required String toWarehouseId,
    required List<StockTransferItemsCompanion> items,
    String? note,
    String? userId,
  }) =>
      operations.transferStock(
          fromWarehouseId: fromWarehouseId,
          toWarehouseId: toWarehouseId,
          items: items,
          note: note,
          userId: userId);
}
