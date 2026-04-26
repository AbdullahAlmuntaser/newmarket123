import '../../domain/entities/sales_invoice.dart';
import 'posting_engine.dart';
import 'inventory_service.dart';

class SalesService {
  final PostingEngine postingEngine;
  final InventoryService inventoryService;

  SalesService(this.postingEngine, this.inventoryService);

  Future<void> processInvoice(SalesInvoice invoice) async {
    // 1. خصم الكميات من المخزون
    for (var item in invoice.items) {
      await inventoryService.deductStock(
        itemId: item.itemId,
        quantity: item.quantity,
        warehouseId: "MAIN_WAREHOUSE",
        referenceId: invoice.id,
      );
    }

    // 2. القيد المحاسبي
    await postingEngine.postEntry(
      entries: [
        PostingLine(
          account: invoice.paymentMethod == 'cash' ? 'CASH_BOX' : 'CUSTOMER_AR',
          debit: invoice.totalAmount,
          credit: 0,
        ),
        PostingLine(
          account: 'SALES_REVENUE',
          debit: 0,
          credit: invoice.subtotal,
        ),
        PostingLine(
          account: 'VAT_PAYABLE',
          debit: 0,
          credit: invoice.taxAmount,
        ),
      ],
      reference: "INV_${invoice.id}",
      date: invoice.timestamp,
    );
  }
}
