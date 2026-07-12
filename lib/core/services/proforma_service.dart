import 'package:drift/drift.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

class ProformaService {
  final AppDatabase db;

  ProformaService(this.db);

  Future<ProformaInvoice> createProforma({
    String? customerId,
    required List<ProformaItemInput> items,
    double discount = 0,
    double taxRate = 15,
    String? notes,
    String? validUntil,
    String? currencyId,
    double exchangeRate = 1.0,
  }) async {
    final id = const Uuid().v4();

    // Calculate totals
    double subtotal = 0;
    for (final item in items) {
      subtotal += item.quantity * item.price * item.unitFactor;
    }

    final discountAmount = subtotal * discount / 100;
    final taxableAmount = subtotal - discountAmount;
    final taxAmount = taxableAmount * taxRate / 100;
    final total = taxableAmount + taxAmount;

    // Insert proforma header
    await db.into(db.proformaInvoices).insert(
          ProformaInvoicesCompanion.insert(
            id: Value(id),
            customerId: Value(customerId),
            total: Decimal.parse(total.toStringAsFixed(2)),
            discount: Value(Decimal.parse(discountAmount.toStringAsFixed(2))),
            tax: Value(Decimal.parse(taxAmount.toStringAsFixed(2))),
            currencyId: Value(currencyId),
            exchangeRate: Value(Decimal.parse(exchangeRate.toStringAsFixed(6))),
            notes: Value(notes),
            validUntil: Value(validUntil),
          ),
        );

    // Insert items
    for (final item in items) {
      await db.into(db.proformaInvoiceItems).insert(
            ProformaInvoiceItemsCompanion.insert(
              id: Value(const Uuid().v4()),
              proformaId: id,
              productId: item.productId,
              quantity: Decimal.parse(item.quantity.toStringAsFixed(3)),
              price: Decimal.parse(item.price.toStringAsFixed(2)),
              unitId: Value(item.unitId),
              unitName: Value(item.unitName),
              unitFactor: Value(Decimal.parse(item.unitFactor.toStringAsFixed(6))),
              discount: Value(Decimal.parse(item.discount.toStringAsFixed(2))),
              taxRate: Value(Decimal.parse(taxRate.toStringAsFixed(2))),
            ),
          );
    }

    return await getProforma(id);
  }

  Future<ProformaInvoice> getProforma(String id) async {
    return await (db.select(db.proformaInvoices)
          ..where((p) => p.id.equals(id)))
        .getSingle();
  }

  Future<List<ProformaInvoice>> getAllProformas({
    String? customerId,
    DocumentStatus? status,
  }) async {
    final query = db.select(db.proformaInvoices);

    if (customerId != null) {
      query.where((p) => p.customerId.equals(customerId));
    }
    if (status != null) {
      query.where((p) => p.status.equals(status.index));
    }

    query.orderBy([(p) => OrderingTerm.desc(p.createdAt)]);
    return await query.get();
  }

  Future<List<ProformaInvoiceItem>> getProformaItems(String proformaId) async {
    return await (db.select(db.proformaInvoiceItems)
          ..where((i) => i.proformaId.equals(proformaId)))
        .get();
  }

  Future<void> updateStatus(String id, DocumentStatus status) async {
    await (db.update(db.proformaInvoices)..where((p) => p.id.equals(id)))
        .write(ProformaInvoicesCompanion(
      status: Value(status),
    ));
  }

  Future<void> cancelProforma(String id) async {
    await updateStatus(id, DocumentStatus.cancelled);
  }

  /// Convert proforma to sale invoice
  Future<void> convertToSale(String proformaId) async {
    await updateStatus(proformaId, DocumentStatus.posted);
  }
}

class ProformaItemInput {
  final String productId;
  final double quantity;
  final double price;
  final String? unitId;
  final String unitName;
  final double unitFactor;
  final double discount;

  const ProformaItemInput({
    required this.productId,
    required this.quantity,
    required this.price,
    this.unitId,
    this.unitName = 'حبة',
    this.unitFactor = 1.0,
    this.discount = 0,
  });
}
