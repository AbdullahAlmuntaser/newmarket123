import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

/// Service for managing inventory reservations.
/// Allows reserving stock for sales orders before fulfillment.
class InventoryReservationService {
  final AppDatabase db;

  InventoryReservationService(this.db);

  /// Create an inventory reservation
  Future<InventoryReservation> createReservation({
    required String productId,
    required String warehouseId,
    required String referenceType,
    required String referenceId,
    required Decimal reservedQuantity,
    DateTime? expiryDate,
  }) async {
    // Check available stock
    final availableStock = await _getAvailableStock(productId, warehouseId);

    if (availableStock < reservedQuantity) {
      throw Exception('المخزون المتاح ($availableStock) أقل من الكمية المطلوب حجزها ($reservedQuantity)');
    }

    final id = const Uuid().v4();
    await db.into(db.inventoryReservations).insert(
          InventoryReservationsCompanion.insert(
            id: Value(id),
            productId: productId,
            warehouseId: warehouseId,
            referenceType: referenceType,
            referenceId: referenceId,
            reservedQuantity: reservedQuantity,
            expiryDate: Value(expiryDate),
          ),
        );

    return await (db.select(db.inventoryReservations)
          ..where((ir) => ir.id.equals(id)))
        .getSingle();
  }

  /// Get available stock (total stock minus reserved)
  Future<Decimal> _getAvailableStock(String productId, String warehouseId) async {
    // Get total stock
    final product = await (db.select(db.products)
          ..where((p) => p.id.equals(productId)))
        .getSingleOrNull();

    if (product == null) return Decimal.zero;

    // Get reserved quantity
    final reservations = await (db.select(db.inventoryReservations)
          ..where((ir) => ir.productId.equals(productId))
          ..where((ir) => ir.warehouseId.equals(warehouseId))
          ..where((ir) => ir.status.equals('ACTIVE') | ir.status.equals('PARTIAL')))
        .get();

    Decimal totalReserved = Decimal.zero;
    for (final reservation in reservations) {
      totalReserved += reservation.reservedQuantity - reservation.fulfilledQuantity;
    }

    return product.stock - totalReserved;
  }

  /// Fulfill a reservation (when stock is picked)
  Future<void> fulfillReservation({
    required String reservationId,
    required Decimal fulfilledQuantity,
  }) async {
    final reservation = await (db.select(db.inventoryReservations)
          ..where((ir) => ir.id.equals(reservationId)))
        .getSingleOrNull();

    if (reservation == null) throw Exception('الحجز غير موجود');

    final remaining = reservation.reservedQuantity - reservation.fulfilledQuantity;
    if (fulfilledQuantity > remaining) {
      throw Exception('الكمية المطلوب تخطي ($fulfilledQuantity) تتجاوز المتبقي ($remaining)');
    }

    final newFulfilled = reservation.fulfilledQuantity + fulfilledQuantity;
    final newStatus = newFulfilled >= reservation.reservedQuantity ? 'COMPLETED' : 'PARTIAL';

    await (db.update(db.inventoryReservations)
          ..where((ir) => ir.id.equals(reservationId)))
        .write(InventoryReservationsCompanion(
      fulfilledQuantity: Value(newFulfilled),
      status: Value(newStatus),
    ));
  }

  /// Cancel a reservation
  Future<void> cancelReservation(String reservationId) async {
    await (db.update(db.inventoryReservations)
          ..where((ir) => ir.id.equals(reservationId)))
        .write(const InventoryReservationsCompanion(
      status: Value('CANCELLED'),
    ));
  }

  /// Get reservations for a reference (e.g., sales order)
  Future<List<InventoryReservation>> getReservationsForReference({
    required String referenceType,
    required String referenceId,
  }) async {
    return await (db.select(db.inventoryReservations)
          ..where((ir) => ir.referenceType.equals(referenceType))
          ..where((ir) => ir.referenceId.equals(referenceId))
          ..orderBy([(ir) => OrderingTerm.desc(ir.reservationDate)]))
        .get();
  }

  /// Get all active reservations for a product
  Future<List<InventoryReservation>> getActiveReservations({
    required String productId,
    String? warehouseId,
  }) async {
    final query = db.select(db.inventoryReservations)
      ..where((ir) => ir.productId.equals(productId))
      ..where((ir) => ir.status.equals('ACTIVE') | ir.status.equals('PARTIAL'));

    if (warehouseId != null) {
      query.where((ir) => ir.warehouseId.equals(warehouseId));
    }

    return await query.get();
  }

  /// Clean up expired reservations
  Future<int> cleanupExpiredReservations() async {
    final now = DateTime.now();
    final expired = await (db.select(db.inventoryReservations)
          ..where((ir) => ir.expiryDate.isSmallerThanValue(now))
          ..where((ir) => ir.status.equals('ACTIVE')))
        .get();

    for (final reservation in expired) {
      await cancelReservation(reservation.id);
    }

    return expired.length;
  }
}
