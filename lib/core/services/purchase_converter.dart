import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:uuid/uuid.dart';

class PurchaseConverter {
  final AppDatabase db;

  PurchaseConverter(this.db);

  Future<void> convertOrderToInvoice(String orderId) async {
    await db.transaction(() async {
      // 1. جلب بيانات أمر الشراء
      final order = await (db.select(db.purchaseOrders)
            ..where((o) => o.id.equals(orderId)))
          .getSingle();
      final orderItems = await (db.select(db.purchaseOrderItems)
            ..where((i) => i.orderId.equals(orderId)))
          .get();

      // 2. إنشاء فاتورة شراء جديدة
      final invoiceId = const Uuid().v4();
      await db.into(db.purchases).insert(PurchasesCompanion.insert(
            id: Value(invoiceId),
            supplierId: Value(order.supplierId),
            total: Decimal.parse(order.total.toString()),
            status: const Value(DocumentStatus.draft),
            date: Value(DateTime.now()),
            invoiceNumber:
                Value('INV-${order.orderNumber ?? orderId.substring(0, 8)}'),
          ));

      // 3. نقل الأصناف
      for (var item in orderItems) {
        await db.into(db.purchaseItems).insert(PurchaseItemsCompanion.insert(
              purchaseId: invoiceId,
              productId: item.productId,
              quantity: Decimal.parse(item.quantity.toString()),
              unitPrice: Decimal.parse(item.price.toString()),
              price: Decimal.parse((item.quantity * item.price).toString()),
            ));
      }

      // 4. تحديث حالة أمر الشراء
      await (db.update(db.purchaseOrders)..where((o) => o.id.equals(orderId)))
          .write(
        const PurchaseOrdersCompanion(
          status: Value('CONVERTED'),
        ),
      );
    });
  }
}
