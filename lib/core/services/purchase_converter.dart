import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

class PurchaseConverter {
  final AppDatabase db;

  PurchaseConverter(this.db);

  Future<void> convertOrderToInvoice(String orderId) async {
    await db.transaction(() async {
      // 1. جلب بيانات أمر الشراء
      final order = await (db.select(db.purchaseOrders)..where((o) => o.id.equals(orderId))).getSingle();
      final orderItems = await (db.select(db.purchaseOrderItems)..where((i) => i.orderId.equals(orderId))).get();

      // 2. إنشاء فاتورة شراء جديدة
      final invoiceId = const Uuid().v4();
      await db.into(db.purchases).insert(PurchasesCompanion.insert(
        id: Value(invoiceId),
        supplierId: Value(order.supplierId),
        total: order.total,
        status: const Value('DRAFT'),
        date: Value(DateTime.now()),
        invoiceNumber: Value('INV-${order.orderNumber ?? orderId.substring(0, 8)}'),
      ));

      // 3. نقل الأصناف
      for (var item in orderItems) {
        await db.into(db.purchaseItems).insert(PurchaseItemsCompanion.insert(
          purchaseId: invoiceId,
          productId: item.productId,
          quantity: item.quantity,
          unitPrice: item.price,
          price: item.quantity * item.price,
        ));
      }

      // 4. تحديث حالة أمر الشراء
      await (db.update(db.purchaseOrders)..where((o) => o.id.equals(orderId))).write(PurchaseOrdersCompanion(
        status: const Value('CONVERTED'),
      ));
    });
  }
}
