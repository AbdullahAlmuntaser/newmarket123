import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../data/datasources/local/app_database.dart';
import '../constants/app_enums.dart';

class SalesOrderService {
  final AppDatabase db;

  SalesOrderService(this.db);

  Future<List<SalesOrder>> getAllOrders() async {
    return (db.select(db.salesOrders)
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .get();
  }

  Stream<List<SalesOrder>> watchAllOrders() {
    return (db.select(db.salesOrders)
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .watch();
  }

  Future<SalesOrder?> getOrderById(String orderId) async {
    return (db.select(db.salesOrders)..where((o) => o.id.equals(orderId)))
        .getSingleOrNull();
  }

  Future<List<SalesOrderItem>> getOrderItems(String orderId) async {
    return (db.select(db.salesOrderItems)
          ..where((i) => i.orderId.equals(orderId)))
        .get();
  }

  Stream<List<SalesOrderItem>> watchOrderItems(String orderId) {
    return (db.select(db.salesOrderItems)
          ..where((i) => i.orderId.equals(orderId)))
        .watch();
  }

  Future<List<SalesOrder>> getOrdersByStatus(String status) async {
    return (db.select(db.salesOrders)
          ..where((o) => o.status.equals(status))
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .get();
  }

  Stream<List<SalesOrder>> watchOrdersByStatus(String status) {
    return (db.select(db.salesOrders)
          ..where((o) => o.status.equals(status))
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .watch();
  }

  Future<List<SalesOrder>> getOrdersByCustomer(String customerId) async {
    return (db.select(db.salesOrders)
          ..where((o) => o.customerId.equals(customerId))
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .get();
  }

  Future<String> _generateOrderNumber() async {
    final now = DateTime.now();
    final prefix =
        'SO${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final count = await db.customSelect(
      "SELECT COUNT(*) as cnt FROM sales_orders WHERE order_number LIKE ?",
      variables: [Variable.withString('$prefix%')],
    ).getSingle();
    final seq = (count.data['cnt'] as int) + 1;
    return '$prefix${seq.toString().padLeft(4, '0')}';
  }

  Future<SalesOrder> createOrder({
    required String? customerId,
    required List<SalesOrderItemData> items,
    String? notes,
    String? userId,
  }) async {
    if (items.isEmpty) {
      throw Exception('لا يمكن إنشاء طلبية بدون أصناف.');
    }

    Decimal total = Decimal.zero;
    for (final item in items) {
      total += item.price * item.quantity;
    }

    final orderId = const Uuid().v4();
    final orderNumber = await _generateOrderNumber();

    return db.transaction(() async {
      await db.into(db.salesOrders).insert(
            SalesOrdersCompanion.insert(
              id: Value(orderId),
              customerId: Value(customerId),
              total: Value(total),
              orderNumber: Value(orderNumber),
              status: const Value('PENDING'),
              notes: Value(notes),
            ),
          );

      for (final item in items) {
        await db.into(db.salesOrderItems).insert(
              SalesOrderItemsCompanion.insert(
                id: Value(const Uuid().v4()),
                orderId: orderId,
                productId: item.productId,
                quantity: Value(item.quantity),
                price: Value(item.price),
                unitId: Value(item.unitId),
              ),
            );
      }

      await db.into(db.auditLogs).insert(
            AuditLogsCompanion.insert(
              userId: Value(userId),
              action: 'CREATE',
              targetEntity: 'SALES_ORDER',
              entityId: orderId,
              details: Value('Created sales order: $orderNumber'),
            ),
          );

      return (db.select(db.salesOrders)..where((o) => o.id.equals(orderId)))
          .getSingle();
    });
  }

  Future<void> updateOrder({
    required String orderId,
    String? customerId,
    required List<SalesOrderItemData> items,
    String? notes,
    String? userId,
  }) async {
    if (items.isEmpty) {
      throw Exception('لا يمكن تحديث طلبية بدون أصناف.');
    }

    Decimal total = Decimal.zero;
    for (final item in items) {
      total += item.price * item.quantity;
    }

    await db.transaction(() async {
      await (db.update(db.salesOrders)..where((o) => o.id.equals(orderId)))
          .write(
        SalesOrdersCompanion(
          customerId: Value(customerId),
          total: Value(total),
          notes: Value(notes),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await (db.delete(db.salesOrderItems)
            ..where((i) => i.orderId.equals(orderId)))
          .go();

      for (final item in items) {
        await db.into(db.salesOrderItems).insert(
              SalesOrderItemsCompanion.insert(
                id: Value(const Uuid().v4()),
                orderId: orderId,
                productId: item.productId,
                quantity: Value(item.quantity),
                price: Value(item.price),
                unitId: Value(item.unitId),
              ),
            );
      }

      await db.into(db.auditLogs).insert(
            AuditLogsCompanion.insert(
              userId: Value(userId),
              action: 'UPDATE',
              targetEntity: 'SALES_ORDER',
              entityId: orderId,
              details: Value('Updated sales order: $orderId'),
            ),
          );
    });
  }

  Future<void> updateStatus(String orderId, String newStatus,
      {String? userId}) async {
    await db.transaction(() async {
      await (db.update(db.salesOrders)..where((o) => o.id.equals(orderId)))
          .write(
        SalesOrdersCompanion(
          status: Value(newStatus),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await db.into(db.auditLogs).insert(
            AuditLogsCompanion.insert(
              userId: Value(userId),
              action: 'UPDATE',
              targetEntity: 'SALES_ORDER',
              entityId: orderId,
              details: Value('Updated order status to: $newStatus'),
            ),
          );
    });
  }

  Future<void> deleteOrder(String orderId, {String? userId}) async {
    await db.transaction(() async {
      await (db.delete(db.salesOrderItems)
            ..where((i) => i.orderId.equals(orderId)))
          .go();
      await (db.delete(db.salesOrders)..where((o) => o.id.equals(orderId)))
          .go();

      await db.into(db.auditLogs).insert(
            AuditLogsCompanion.insert(
              userId: Value(userId),
              action: 'DELETE',
              targetEntity: 'SALES_ORDER',
              entityId: orderId,
              details: const Value('Deleted sales order'),
            ),
          );
    });
  }

  Future<Sale> convertToSale(String orderId, {String? userId}) async {
    final order = await getOrderById(orderId);
    if (order == null) throw Exception('الطلبية غير موجودة.');
    if (order.status == 'CANCELLED') {
      throw Exception('لا يمكن تحويل طلبية ملغاة.');
    }
    if (order.status == 'INVOICED') {
      throw Exception('تم تحويل هذه الطلبية بالفعل.');
    }

    final items = await getOrderItems(orderId);
    if (items.isEmpty) throw Exception('الطلبية لا تحتوي على أصناف.');

    final saleId = const Uuid().v4();

    await db.transaction(() async {
      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: Value(saleId),
              customerId: Value(order.customerId),
              total: order.total,
              paymentMethod: PaymentMethod.cash,
              status: const Value(DocumentStatus.draft),
              saleType: const Value('ORDER'),
            ),
          );

      for (final item in items) {
        await db.into(db.saleItems).insert(
              SaleItemsCompanion.insert(
                id: Value(const Uuid().v4()),
                saleId: saleId,
                productId: item.productId,
                quantity: item.quantity,
                price: item.price,
                unitId: Value(item.unitId),
              ),
            );
      }

      await updateStatus(orderId, 'INVOICED', userId: userId);

      await db.into(db.auditLogs).insert(
            AuditLogsCompanion.insert(
              userId: Value(userId),
              action: 'CONVERT',
              targetEntity: 'SALES_ORDER',
              entityId: orderId,
              details: Value('Converted order to sale: $saleId'),
            ),
          );
    });

    return (db.select(db.sales)..where((s) => s.id.equals(saleId))).getSingle();
  }

  Future<void> cancelOrder(String orderId, {String? userId}) async {
    final order = await getOrderById(orderId);
    if (order == null) throw Exception('الطلبية غير موجودة.');
    if (order.status == 'INVOICED') {
      throw Exception('لا يمكن إلغاء طلبية محولة لفاتورة.');
    }
    await updateStatus(orderId, 'CANCELLED', userId: userId);
  }

  Future<int> getOrdersCountByStatus(String status) async {
    final result = await db.customSelect(
      "SELECT COUNT(*) as cnt FROM sales_orders WHERE status = ?",
      variables: [Variable.withString(status)],
    ).getSingle();
    return result.data['cnt'] as int;
  }
}

class SalesOrderItemData {
  final String productId;
  final Decimal quantity;
  final Decimal price;
  final String? unitId;

  SalesOrderItemData({
    required this.productId,
    required this.quantity,
    required this.price,
    this.unitId,
  });
}
