import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

/// Service for tracking serial numbers on products.
/// Used for warranty tracking, recalls, and high-value items.
class SerialNumberService {
  final AppDatabase db;

  SerialNumberService(this.db);

  /// Register a serial number for a product (received via purchase)
  Future<SerialNumber> registerSerialNumber({
    required String productId,
    required String serialNumber,
    required String warehouseId,
    String? batchId,
    String? purchaseId,
  }) async {
    // Check if serial number already exists
    final existing = await (db.select(db.serialNumbers)
          ..where((sn) => sn.serialNumber.equals(serialNumber)))
        .getSingleOrNull();

    if (existing != null) {
      throw Exception('رقم التسلسل موجود بالفعل: $serialNumber');
    }

    final id = const Uuid().v4();
    await db.into(db.serialNumbers).insert(
          SerialNumbersCompanion.insert(
            id: Value(id),
            productId: productId,
            serialNumber: serialNumber,
            warehouseId: warehouseId,
            batchId: Value(batchId),
            referenceId: Value(purchaseId),
            receivedDate: Value(DateTime.now()),
          ),
        );

    return await (db.select(db.serialNumbers)..where((sn) => sn.id.equals(id)))
        .getSingle();
  }

  /// Mark a serial number as sold (linked to a sale)
  Future<void> markAsSold({
    required String serialNumberId,
    required String saleId,
  }) async {
    await (db.update(db.serialNumbers)
          ..where((sn) => sn.id.equals(serialNumberId)))
        .write(SerialNumbersCompanion(
      status: const Value('SOLD'),
      referenceId: Value(saleId),
      soldDate: Value(DateTime.now()),
    ));
  }

  /// Mark a serial number as returned
  Future<void> markAsReturned({
    required String serialNumberId,
    String? warehouseId,
  }) async {
    await (db.update(db.serialNumbers)
          ..where((sn) => sn.id.equals(serialNumberId)))
        .write(SerialNumbersCompanion(
      status: const Value('RETURNED'),
      referenceId: const Value.absent(),
      soldDate: const Value.absent(),
      warehouseId: warehouseId != null ? Value(warehouseId) : const Value.absent(),
    ));
  }

  /// Reserve a serial number for a sales order
  Future<void> reserve({
    required String serialNumberId,
    required String salesOrderId,
  }) async {
    await (db.update(db.serialNumbers)
          ..where((sn) => sn.id.equals(serialNumberId)))
        .write(SerialNumbersCompanion(
      status: const Value('RESERVED'),
      referenceId: Value(salesOrderId),
    ));
  }

  /// Get serial numbers for a product
  Future<List<SerialNumber>> getSerialNumbersForProduct({
    required String productId,
    String? warehouseId,
    String? status,
  }) async {
    final query = db.select(db.serialNumbers)
      ..where((sn) => sn.productId.equals(productId));

    if (warehouseId != null) {
      query.where((sn) => sn.warehouseId.equals(warehouseId));
    }
    if (status != null) {
      query.where((sn) => sn.status.equals(status));
    }

    query.orderBy([(sn) => OrderingTerm.asc(sn.serialNumber)]);
    return await query.get();
  }

  /// Get serial number by serial number string
  Future<SerialNumber?> getSerialNumber(String serialNumber) async {
    return await (db.select(db.serialNumbers)
          ..where((sn) => sn.serialNumber.equals(serialNumber)))
        .getSingleOrNull();
  }

  /// Get serial number history
  Future<List<SerialNumber>> getSerialNumberHistory({
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = db.select(db.serialNumbers);

    if (productId != null) {
      query.where((sn) => sn.productId.equals(productId));
    }
    if (startDate != null) {
      query.where((sn) =>
          sn.receivedDate.isBiggerOrEqualValue(startDate) |
          sn.soldDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((sn) =>
          sn.receivedDate.isSmallerOrEqualValue(endDate) |
          sn.soldDate.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(sn) => OrderingTerm.desc(sn.createdAt)]);
    return await query.get();
  }

  /// Get available serial numbers for a product in a warehouse
  Future<List<SerialNumber>> getAvailableSerialNumbers({
    required String productId,
    required String warehouseId,
  }) async {
    return await getSerialNumbersForProduct(
      productId: productId,
      warehouseId: warehouseId,
      status: 'IN_STOCK',
    );
  }

  /// Bulk register serial numbers
  Future<int> bulkRegister({
    required String productId,
    required String warehouseId,
    required List<String> serialNumbers,
    String? purchaseId,
  }) async {
    int registered = 0;
    for (final sn in serialNumbers) {
      try {
        await registerSerialNumber(
          productId: productId,
          serialNumber: sn,
          warehouseId: warehouseId,
          purchaseId: purchaseId,
        );
        registered++;
      } catch (_) {
        // Skip duplicates
      }
    }
    return registered;
  }
}
