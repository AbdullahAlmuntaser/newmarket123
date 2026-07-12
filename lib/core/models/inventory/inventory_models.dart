import 'package:supermarket/data/datasources/local/app_database.dart';

class InventoryTransactionReport {
  final InventoryTransaction transaction;
  final Product product;
  final Warehouse? warehouse;

  InventoryTransactionReport({
    required this.transaction,
    required this.product,
    this.warehouse,
  });
}

class BatchReport {
  final ProductBatch batch;
  final Product product;
  final Warehouse? warehouse;

  BatchReport({required this.batch, required this.product, this.warehouse});
}
