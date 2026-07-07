import 'package:drift/drift.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/utils/drift_extensions.dart';
import 'package:supermarket/core/services/posting_engine.dart';
import 'package:supermarket/core/services/app_config_service.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:uuid/uuid.dart';

class PurchaseService {
  final AppDatabase db;
  final PostingEngine postingEngine;
  final InventoryCostingService inventoryCostingService;
  final AppConfigService configService;

  PurchaseService(this.db, this.postingEngine, this.inventoryCostingService,
      this.configService);

  Future<Purchase> createPurchase({
    required String supplierId,
    required List<PurchaseItemsCompanion> items,
    required double total,
    String? warehouseId,
  }) async {
    final purchaseId = const Uuid().v4();
    final purchase = PurchasesCompanion.insert(
      id: Value(purchaseId),
      supplierId: Value(supplierId),
      date: Value(DateTime.now()),
      total: Decimal.parse(total.toString()),
      status: const Value(DocumentStatus.draft),
      warehouseId: Value(warehouseId),
    );

    await db.into(db.purchases).insert(purchase);

    for (var item in items) {
      await db
          .into(db.purchaseItems)
          .insert(item.copyWith(purchaseId: Value(purchaseId)));
    }

    return await (db.select(
      db.purchases,
    )..where((p) => p.id.equals(purchaseId)))
        .getSingle();
  }

  Future<void> postPurchase(String purchaseId) async {
    try {
      // 0. Check accounting period before any writes
      final period = await (db.select(db.accountingPeriods)
            ..where((p) => p.isClosed.equals(false))
            ..where((p) => p.startDate.isSmallerOrEqual(Variable(DateTime.now())))
            ..where((p) => p.endDate.isBiggerOrEqual(Variable(DateTime.now()))))
          .getFirstOrNull();
      if (period == null) {
        throw Exception('الفترة المحاسبية مغلقة. لا يمكن الترحيل.');
      }

      // 1. Verify that GRN exists for this purchase
      final grn = await (db.select(db.goodReceivedNotes)
            ..where((g) => g.purchaseId.equals(purchaseId))
            ..where((g) => g.status.equals('POSTED')))
          .getSingleOrNull();

      if (grn == null) {
        throw Exception(
            'لا يمكن ترحيل الفاتورة قبل استلام البضاعة (GRN غير موجود أو غير مرحل).');
      }

      // 2. Prevent double posting
      final purchase = await (db.select(db.purchases)
            ..where((p) => p.id.equals(purchaseId)))
          .getSingle();
      if (purchase.status == DocumentStatus.posted) {
        throw Exception('هذه الفاتورة تم ترحيلها بالفعل.');
      }

      final items = await (db.select(db.purchaseItems)
            ..where((i) => i.purchaseId.equals(purchaseId)))
          .get();

      // Pre-check: ensure required GL accounts exist
      final requiredCodes = ['1040', '1050', '2010', '1010'];
      for (final code in requiredCodes) {
        final account = await db.accountingDao.getAccountByCode(code);
        if (account == null) {
          // Auto-seed GL accounts if missing
          await db.seedDefaultGLAccounts();
          await db.seedDefaultPostingProfiles();
          break;
        }
      }

      double subtotal = 0;
      for (var item in items) {
        subtotal +=
            (item.quantity * item.unitFactor * item.unitPrice).toDouble();
      }

      // حساب إجمالي المصاريف الإضافية
      double totalExpenses =
          (purchase.shippingCost + purchase.otherExpenses).toDouble();

      double discount = purchase.discount.toDouble();

      // استخدام قيمة الضريبة الموجودة في الفاتورة مباشرة
      double tax =
          (purchase.tax > Decimal.zero) ? purchase.tax.toDouble() : 0.0;

      await postingEngine.post(
        type: TransactionType.purchase,
        referenceId: purchaseId,
        context: {
          'subtotal': subtotal,
          'discount': discount,
          'tax': tax,
          'expenses': totalExpenses,
          'total': subtotal - discount + tax + totalExpenses,
          'amount': subtotal - discount + tax + totalExpenses,
          'supplierId': purchase.supplierId,
          'description':
              'Purchase Invoice #${purchase.invoiceNumber ?? purchase.id.substring(0, 8)}',
        },
      );

      // Update Purchase status to COMPLETED
      await (db.update(db.purchases)..where((p) => p.id.equals(purchaseId)))
          .write(
        const PurchasesCompanion(status: Value(DocumentStatus.posted)),
      );
    } catch (e, stackTrace) {
      throw Exception(
          'خطأ في ترحيل فاتورة الشراء $purchaseId: $e\n$stackTrace');
    }
  }
}
