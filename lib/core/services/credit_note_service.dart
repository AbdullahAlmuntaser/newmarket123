import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

/// Service for managing credit notes (سندات الائتمان).
/// Used for customer refunds, price adjustments, and returns.
class CreditNoteService {
  final AppDatabase db;

  CreditNoteService(this.db);

  /// Create a credit note
  Future<CreditNote> createCreditNote({
    required String customerId,
    required String saleId,
    required String reason,
    required List<CreditNoteItemData> items,
  }) async {
    // Validate sale exists
    final sale = await (db.select(db.sales)
          ..where((s) => s.id.equals(saleId)))
        .getSingleOrNull();

    if (sale == null) throw Exception('فاتورة المبيعات غير موجودة');

    // Calculate totals
    Decimal totalAmount = Decimal.zero;
    Decimal taxAmount = Decimal.zero;

    for (final item in items) {
      final itemTotal = item.quantity * item.unitPrice;
      totalAmount += itemTotal;
    }

    // Generate invoice number
    final invoiceNumber = 'CN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    final id = const Uuid().v4();
    await db.into(db.creditNotes).insert(
          CreditNotesCompanion.insert(
            id: Value(id),
            invoiceNumber: invoiceNumber,
            customerId: customerId,
            saleId: saleId,
            totalAmount: totalAmount,
            taxAmount: Value(taxAmount),
            reason: reason,
          ),
        );

    // Insert items
    for (final item in items) {
      await db.into(db.creditNoteItems).insert(
            CreditNoteItemsCompanion.insert(
              creditNoteId: id,
              productId: item.productId,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              total: item.quantity * item.unitPrice,
            ),
          );
    }

    return await (db.select(db.creditNotes)..where((cn) => cn.id.equals(id)))
        .getSingle();
  }

  /// Post a credit note (apply to customer balance)
  Future<void> postCreditNote(String creditNoteId, {String? userId}) async {
    final creditNote = await (db.select(db.creditNotes)
          ..where((cn) => cn.id.equals(creditNoteId)))
        .getSingleOrNull();

    if (creditNote == null) throw Exception('سند الائتمان غير موجود');
    if (creditNote.status == 'POSTED') throw Exception('سند الائتمان مرحّل بالفعل');

    // Update customer balance
    final customer = await (db.select(db.customers)
          ..where((c) => c.id.equals(creditNote.customerId)))
        .getSingle();

    await (db.update(db.customers)..where((c) => c.id.equals(creditNote.customerId)))
        .write(CustomersCompanion(
      balance: Value(customer.balance - creditNote.totalAmount),
    ));

    // Create GL entry
    // Debit: Revenue (or Sales Returns)
    // Credit: Accounts Receivable
    final items = await (db.select(db.creditNoteItems)
          ..where((cni) => cni.creditNoteId.equals(creditNoteId)))
        .get();

    for (final item in items) {
      final product = await (db.select(db.products)
            ..where((p) => p.id.equals(item.productId)))
          .getSingleOrNull();

      // Record inventory return if applicable
      if (product != null && !product.isService) {
        await db.into(db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: item.productId,
                quantity: item.quantity,
                movementDate: Value(DateTime.now()),
                type: 'CREDIT_NOTE',
                referenceId: Value(creditNoteId),
              ),
            );

        await (db.update(db.products)
              ..where((p) => p.id.equals(item.productId)))
            .write(ProductsCompanion(
          stock: Value(product.stock + item.quantity),
        ));
      }
    }

    // Update credit note status
    await (db.update(db.creditNotes)
          ..where((cn) => cn.id.equals(creditNoteId)))
        .write(CreditNotesCompanion(
      status: const Value('POSTED'),
      postedBy: Value(userId),
      postedAt: Value(DateTime.now()),
    ));
  }

  /// Get all credit notes
  Future<List<CreditNote>> getCreditNotes({
    String? customerId,
    String? status,
  }) async {
    final query = db.select(db.creditNotes);

    if (customerId != null) {
      query.where((cn) => cn.customerId.equals(customerId));
    }
    if (status != null) {
      query.where((cn) => cn.status.equals(status));
    }

    query.orderBy([(cn) => OrderingTerm.desc(cn.createdAt)]);
    return await query.get();
  }

  /// Get credit note with items
  Future<CreditNoteWithItems?> getCreditNoteWithItems(String creditNoteId) async {
    final creditNote = await (db.select(db.creditNotes)
          ..where((cn) => cn.id.equals(creditNoteId)))
        .getSingleOrNull();

    if (creditNote == null) return null;

    final items = await (db.select(db.creditNoteItems)
          ..where((cni) => cni.creditNoteId.equals(creditNoteId)))
        .get();

    return CreditNoteWithItems(creditNote: creditNote, items: items);
  }
}

/// Credit note item data for creation
class CreditNoteItemData {
  final String productId;
  final Decimal quantity;
  final Decimal unitPrice;

  const CreditNoteItemData({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });
}

/// Credit note with items
class CreditNoteWithItems {
  final CreditNote creditNote;
  final List<CreditNoteItem> items;

  const CreditNoteWithItems({
    required this.creditNote,
    required this.items,
  });
}
