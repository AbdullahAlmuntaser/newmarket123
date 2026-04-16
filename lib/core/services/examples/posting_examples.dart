import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/posting_engine.dart';

class SalesPostingExample {
  final AppDatabase db;
  final PostingEngine postingEngine;

  SalesPostingExample(this.db) : postingEngine = PostingEngine(db);

  Future<void> postSaleWithEngine(Sale sale, List<SaleItem> items) async {
    double totalCost = 0;
    for (var item in items) {
      final product = await db.productsDao.getProductById(item.productId);
      if (product != null) {
        totalCost += (item.quantity * item.unitFactor) * product.buyPrice;
      }
    }

    final context = PostingContext(
      operationType: OperationType.sale,
      referenceId: sale.id,
      referenceType: 'SALE',
      date: sale.createdAt,
      description: 'فاتورة مبيعات #${sale.id.substring(0, 8)}',
      customerId: sale.customerId,
      total: sale.total,
      tax: sale.tax,
      cost: totalCost,
      isCredit: sale.isCredit,
      paymentMethod: sale.paymentMethod,
      currencyId: sale.currencyId,
      exchangeRate: sale.exchangeRate,
    );

    await postingEngine.generateEntry(context: context);

    if (totalCost > 0) {
      final cogsContext = PostingContext(
        operationType: OperationType.sale,
        referenceId: sale.id,
        referenceType: 'COGS',
        date: sale.createdAt,
        description: 'تكلفة البضاعة المباعة #${sale.id.substring(0, 8)}',
        customerId: sale.customerId,
        total: sale.total,
        tax: sale.tax,
        cost: totalCost,
        isCredit: sale.isCredit,
        paymentMethod: sale.paymentMethod,
        currencyId: sale.currencyId,
        exchangeRate: sale.exchangeRate,
      );
      await postingEngine.generateCogsEntry(
        context: cogsContext,
        saleId: sale.id,
      );
    }
  }

  Future<void> postSaleWithEngineFromEvent(
    Sale sale,
    List<SaleItem> items,
  ) async {
    await postSaleWithEngine(sale, items);
  }
}

class PurchasePostingExample {
  final AppDatabase db;
  final PostingEngine postingEngine;

  PurchasePostingExample(this.db) : postingEngine = PostingEngine(db);

  Future<void> postPurchaseWithEngine(
    Purchase purchase,
    List<PurchaseItem> items,
  ) async {
    final context = PostingContext(
      operationType: OperationType.purchase,
      referenceId: purchase.id,
      referenceType: 'PURCHASE',
      date: purchase.date,
      description: 'فاتورة مشتريات #${purchase.id.substring(0, 8)}',
      supplierId: purchase.supplierId,
      total: purchase.total,
      tax: purchase.tax,
      cost: 0,
      isCredit: purchase.isCredit,
      paymentMethod: purchase.isCredit ? 'credit' : 'cash',
      currencyId: purchase.currencyId,
      exchangeRate: purchase.exchangeRate,
    );

    await postingEngine.generateEntry(context: context);
  }

  Future<void> postPurchaseWithEngineFromEvent(
    Purchase purchase,
    List<PurchaseItem> items,
  ) async {
    await postPurchaseWithEngine(purchase, items);
  }
}

class SalesReturnPostingExample {
  final AppDatabase db;
  final PostingEngine postingEngine;

  SalesReturnPostingExample(this.db) : postingEngine = PostingEngine(db);

  Future<void> postSalesReturnWithEngine(
    SalesReturn salesReturn,
    List<SalesReturnItem> items,
    Sale originalSale,
  ) async {
    final totalReturned = salesReturn.amountReturned;
    final taxPortion = originalSale.tax > 0
        ? (totalReturned / originalSale.total) * originalSale.tax
        : 0.0;
    final revenuePortion = totalReturned - taxPortion;

    final context = PostingContext(
      operationType: OperationType.salesReturn,
      referenceId: salesReturn.id,
      referenceType: 'SALE_RETURN',
      date: salesReturn.createdAt,
      description: 'مردود مبيعات #${salesReturn.id.substring(0, 8)}',
      customerId: originalSale.customerId,
      total: totalReturned,
      tax: taxPortion,
      cost: revenuePortion,
      isCredit: originalSale.isCredit,
      paymentMethod: originalSale.isCredit ? 'credit' : 'cash',
      currencyId: originalSale.currencyId,
      exchangeRate: originalSale.exchangeRate,
    );

    await postingEngine.generateEntry(context: context);
  }
}

class PurchaseReturnPostingExample {
  final AppDatabase db;
  final PostingEngine postingEngine;

  PurchaseReturnPostingExample(this.db) : postingEngine = PostingEngine(db);

  Future<void> postPurchaseReturnWithEngine(
    PurchaseReturn purchaseReturn,
    List<PurchaseReturnItem> items,
    Purchase originalPurchase,
  ) async {
    final totalReturned = purchaseReturn.amountReturned;
    final taxPortion = originalPurchase.tax > 0
        ? (totalReturned / originalPurchase.total) * originalPurchase.tax
        : 0.0;
    final expensePortion = totalReturned - taxPortion;

    final context = PostingContext(
      operationType: OperationType.purchaseReturn,
      referenceId: purchaseReturn.id,
      referenceType: 'purchaseReturn',
      date: purchaseReturn.createdAt,
      description: 'مردود مشتريات #${purchaseReturn.id.substring(0, 8)}',
      supplierId: originalPurchase.supplierId,
      total: totalReturned,
      tax: taxPortion,
      cost: expensePortion,
      isCredit: originalPurchase.isCredit,
      paymentMethod: originalPurchase.isCredit ? 'credit' : 'cash',
      currencyId: originalPurchase.currencyId,
      exchangeRate: originalPurchase.exchangeRate,
    );

    await postingEngine.generateEntry(context: context);
  }
}

class PaymentsPostingExample {
  final AppDatabase db;
  final PostingEngine postingEngine;

  PaymentsPostingExample(this.db) : postingEngine = PostingEngine(db);

  Future<void> postCustomerPayment({
    required String customerId,
    required double amount,
    required String paymentMethod,
    String? note,
    String? paymentId,
  }) async {
    final context = PostingContext(
      operationType: OperationType.customerPayment,
      referenceId: paymentId,
      referenceType: 'RECEIPT',
      date: DateTime.now(),
      description: 'سند قبض من العميل',
      customerId: customerId,
      total: amount,
      tax: 0,
      cost: 0,
      isCredit: false,
      paymentMethod: paymentMethod,
    );

    await postingEngine.generateEntry(context: context);
  }

  Future<void> postSupplierPayment({
    required String supplierId,
    required double amount,
    required String paymentMethod,
    String? note,
    String? paymentId,
  }) async {
    final context = PostingContext(
      operationType: OperationType.supplierPayment,
      referenceId: paymentId,
      referenceType: 'PAYMENT',
      date: DateTime.now(),
      description: 'سند صرف للمورد',
      supplierId: supplierId,
      total: amount,
      tax: 0,
      cost: 0,
      isCredit: false,
      paymentMethod: paymentMethod,
    );

    await postingEngine.generateEntry(context: context);
  }
}
