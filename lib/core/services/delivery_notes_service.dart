import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

/// Service for managing delivery notes linked to sales orders.
/// Handles creation, completion, and cancellation of delivery notes.
class DeliveryNotesService {
  final AppDatabase db;

  DeliveryNotesService(this.db);

  /// Create a delivery note from a sales order
  Future<DeliveryNote> createDeliveryNote({
    required String salesOrderId,
    required String warehouseId,
    String? deliveredBy,
    String? notes,
  }) async {
    // Validate sales order exists
    final salesOrder = await (db.select(db.salesOrders)
          ..where((so) => so.id.equals(salesOrderId)))
        .getSingleOrNull();

    if (salesOrder == null) {
      throw Exception('أمر البيع غير موجود');
    }

    if (salesOrder.status == SalesOrderStatus.cancelled) {
      throw Exception('لا يمكن إنشاء توصيل لأمر بيع ملغي');
    }

    // Get order items
    final orderItems = await (db.select(db.salesOrderItems)
          ..where((soi) => soi.orderId.equals(salesOrderId)))
        .get();

    if (orderItems.isEmpty) {
      throw Exception('أمر البيع لا يحتوي على أصناف');
    }

    // Generate delivery number
    final deliveryNumber = 'DN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    // Create delivery note
    final deliveryNoteId = const Uuid().v4();
    await db.into(db.deliveryNotes).insert(
          DeliveryNotesCompanion.insert(
            id: Value(deliveryNoteId),
            saleOrderId: salesOrderId,
            warehouseId: warehouseId,
            deliveryNumber: deliveryNumber,
            deliveredBy: Value(deliveredBy),
            notes: Value(notes),
            status: const Value('DRAFT'),
            syncStatus: const Value(1),
          ),
        );

    // Create delivery note items from order items
    for (final orderItem in orderItems) {
      await db.into(db.deliveryNoteItems).insert(
            DeliveryNoteItemsCompanion(
              deliveryNoteId: Value(deliveryNoteId),
              productId: Value(orderItem.productId),
              quantity: Value(orderItem.quantity),
            ),
          );
    }

    // Return the created delivery note
    final deliveryNote = await (db.select(db.deliveryNotes)
          ..where((dn) => dn.id.equals(deliveryNoteId)))
        .getSingle();

    return deliveryNote;
  }

  /// Complete a delivery note - deducts stock from warehouse
  Future<void> completeDeliveryNote(String deliveryNoteId) async {
    final deliveryNote = await (db.select(db.deliveryNotes)
          ..where((dn) => dn.id.equals(deliveryNoteId)))
        .getSingleOrNull();

    if (deliveryNote == null) {
      throw Exception('سند التوصيل غير موجود');
    }

    if (deliveryNote.status == 'COMPLETED') {
      throw Exception('سند التوصيل مكتمل بالفعل');
    }

    // Get delivery note items
    final items = await (db.select(db.deliveryNoteItems)
          ..where((dni) => dni.deliveryNoteId.equals(deliveryNoteId)))
        .get();

    // Deduct stock for each item
    for (final item in items) {
      // Create stock movement
      await db.into(db.stockMovements).insert(
            StockMovementsCompanion(
              productId: Value(item.productId),
              fromWarehouseId: Value(deliveryNote.warehouseId),
              quantity: Value(item.quantity),
              movementDate: Value(DateTime.now()),
              type: const Value('DELIVERY'),
            ),
          );

      // Update product stock
      final product = await (db.select(db.products)
            ..where((p) => p.id.equals(item.productId)))
          .getSingleOrNull();

      if (product != null && !product.isService) {
        await (db.update(db.products)..where((p) => p.id.equals(item.productId)))
            .write(
          ProductsCompanion(
            stock: Value(product.stock - item.quantity),
          ),
        );
      }
    }

    // Update delivery note status
    await (db.update(db.deliveryNotes)
          ..where((dn) => dn.id.equals(deliveryNoteId)))
        .write(
      const DeliveryNotesCompanion(status: Value('COMPLETED')),
    );
  }

  /// Cancel a delivery note
  Future<void> cancelDeliveryNote(String deliveryNoteId) async {
    final deliveryNote = await (db.select(db.deliveryNotes)
          ..where((dn) => dn.id.equals(deliveryNoteId)))
        .getSingleOrNull();

    if (deliveryNote == null) {
      throw Exception('سند التوصيل غير موجود');
    }

    if (deliveryNote.status == 'COMPLETED') {
      throw Exception('لا يمكن إلغاء سند توصيل مكتمل. يجب إلغاء التوصيل أولاً.');
    }

    await (db.update(db.deliveryNotes)
          ..where((dn) => dn.id.equals(deliveryNoteId)))
        .write(
      const DeliveryNotesCompanion(status: Value('CANCELLED')),
    );
  }

  /// Get all delivery notes for a sales order
  Future<List<DeliveryNote>> getDeliveryNotesForOrder(String salesOrderId) async {
    return await (db.select(db.deliveryNotes)
          ..where((dn) => dn.saleOrderId.equals(salesOrderId))
          ..orderBy([(dn) => OrderingTerm.desc(dn.createdAt)]))
        .get();
  }

  /// Get delivery note with items
  Future<DeliveryNoteWithItems?> getDeliveryNoteWithItems(String deliveryNoteId) async {
    final deliveryNote = await (db.select(db.deliveryNotes)
          ..where((dn) => dn.id.equals(deliveryNoteId)))
        .getSingleOrNull();

    if (deliveryNote == null) return null;

    final items = await (db.select(db.deliveryNoteItems)
          ..where((dni) => dni.deliveryNoteId.equals(deliveryNoteId)))
        .get();

    return DeliveryNoteWithItems(deliveryNote: deliveryNote, items: items);
  }

  /// Get all delivery notes with optional status filter
  Future<List<DeliveryNote>> getAllDeliveryNotes({String? status}) async {
    final query = db.select(db.deliveryNotes);
    if (status != null) {
      query.where((dn) => dn.status.equals(status));
    }
    query.orderBy([(dn) => OrderingTerm.desc(dn.createdAt)]);
    return await query.get();
  }
}

/// Delivery note with its items
class DeliveryNoteWithItems {
  final DeliveryNote deliveryNote;
  final List<DeliveryNoteItem> items;

  const DeliveryNoteWithItems({
    required this.deliveryNote,
    required this.items,
  });
}

/// Sales order status constants (mirrors the enum in the database)
class SalesOrderStatus {
  static const String quotation = 'QUOTATION';
  static const String order = 'ORDER';
  static const String delivered = 'DELIVERED';
  static const String invoiced = 'INVOICED';
  static const String cancelled = 'CANCELLED';
}
