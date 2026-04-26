import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:supermarket/core/events/app_events.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late TransactionEngine engine;
  late EventBusService eventBus;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    eventBus = EventBusService();
    engine = TransactionEngine(db, eventBus);

    // Seed some basic data
    await db
        .into(db.accountingPeriods)
        .insert(
          AccountingPeriodsCompanion.insert(
            id: Value(const Uuid().v4()),
            name: 'Test Period',
            startDate: DateTime.now().subtract(const Duration(days: 30)),
            endDate: DateTime.now().add(const Duration(days: 30)),
            isClosed: const Value(false),
          ),
        );
  });

  tearDown(() async {
    await db.close();
    eventBus.dispose();
  });

  test('TransactionEngine.postSale fires SaleCreatedEvent', () async {
    final saleId = const Uuid().v4();
    final productId = const Uuid().v4();

    await db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            id: Value(productId),
            name: 'Test Product',
            sku: 'TEST-001',
            stock: const Value(10.0),
            sellPrice: const Value(100.0),
          ),
        );

    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            id: Value(saleId),
            total: 100.0,
            paymentMethod: 'Cash',
            status: const Value('DRAFT'),
          ),
        );

    await db
        .into(db.saleItems)
        .insert(
          SaleItemsCompanion.insert(
            saleId: saleId,
            productId: productId,
            quantity: 1.0,
            price: 100.0,
          ),
        );

    bool eventFired = false;
    eventBus.stream.listen((event) {
      if (event is SaleCreatedEvent && event.sale.id == saleId) {
        eventFired = true;
      }
    });

    await engine.postSale(saleId);

    expect(eventFired, isTrue);

    final updatedSale = await (db.select(
      db.sales,
    )..where((s) => s.id.equals(saleId))).getSingle();
    expect(updatedSale.status, 'POSTED');
  });
}
