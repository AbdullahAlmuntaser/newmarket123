import '../../domain/entities/sales_invoice.dart';
import 'posting_engine.dart';
import 'inventory_service.dart';

class SalesService {
  final PostingEngine postingEngine;
  final InventoryService inventoryService;

  SalesService(this.postingEngine, this.inventoryService);

  Future<void> processInvoice(SalesInvoice invoice) async {
    // حساب الإجماليات بدقة
    double subtotal = 0;
    for (var item in invoice.items) {
      // quantity * unit_factor * unit_price
      subtotal += (item.quantity * item.unitFactor * item.price);
    }

    // حساب الخصم والضريبة
    double discount = invoice.discount;
    double tax = (subtotal - discount) * 0.15; // فرض 15% ضريبة مؤقتاً
    double total = subtotal - discount + tax;

    // 1. خصم الكميات من المخزون
    for (var item in invoice.items) {
      await inventoryService.deductStock(
        itemId: item.itemId,
        quantity: item.quantity * item.unitFactor, // تحويل للوحدة الأساسية
        warehouseId: "MAIN_WAREHOUSE",
        referenceId: invoice.id,
      );
    }

    // 2. القيد المحاسبي
    await postingEngine.postEntry(
      entries: [
        PostingLine(
          account: invoice.paymentMethod == 'cash' ? 'CASH_BOX' : 'CUSTOMER_AR',
          debit: total,
          credit: 0,
        ),
        PostingLine(
          account: 'SALES_REVENUE',
          debit: 0,
          credit: subtotal - discount,
        ),
        PostingLine(
          account: 'VAT_PAYABLE',
          debit: 0,
          credit: tax,
        ),
      ],
      reference: "INV_${invoice.id}",
      date: invoice.timestamp,
    );
  }
}
