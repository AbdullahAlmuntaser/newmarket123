import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late TransactionEngine engine;
  late EventBusService eventBus;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    eventBus = EventBusService();
    engine = TransactionEngine(db, eventBus);
  });

  tearDown(() async {
    await db.close();
    eventBus.dispose();
  });

  test('Bill-wise allocation tracks outstanding balances', () async {
    final customerId = const Uuid().v4();
    final saleId = const Uuid().v4();
    final paymentId = const Uuid().v4();

    // 1. Create Customer
    await db.into(db.customers).insert(
      CustomersCompanion.insert(
        id: Value(customerId),
        name: 'Test Customer',
      ),
    );

    // 2. Create Credit Sale
    await db.into(db.sales).insert(
      SalesCompanion.insert(
        id: Value(saleId),
        customerId: Value(customerId),
        total: 500.0,
        paymentMethod: 'credit',
        isCredit: const Value(true),
        status: const Value('POSTED'),
      ),
    );

    // 3. Check outstanding
    var outstanding = await engine.getOutstandingSales(customerId);
    expect(outstanding.length, 1);
    expect(outstanding.first.balance, 500.0);

    // 4. Create Payment (unallocated initially in this test context)
    await db.into(db.customerPayments).insert(
      CustomerPaymentsCompanion.insert(
        id: Value(paymentId),
        customerId: customerId,
        amount: 200.0,
        paymentDate: Value(DateTime.now()),
      ),
    );

    // 5. Allocate Payment to Sale
    await engine.allocatePaymentToSale(
      paymentId: paymentId,
      saleId: saleId,
      amount: 200.0,
    );

    // 6. Check outstanding again
    outstanding = await engine.getOutstandingSales(customerId);
    expect(outstanding.length, 1);
    expect(outstanding.first.balance, 300.0);

    // 7. Fully allocate remaining
    final paymentId2 = const Uuid().v4();
    await db.into(db.customerPayments).insert(
      CustomerPaymentsCompanion.insert(
        id: Value(paymentId2),
        customerId: customerId,
        amount: 300.0,
      ),
    );
    await engine.allocatePaymentToSale(
      paymentId: paymentId2,
      saleId: saleId,
      amount: 300.0,
    );

    // 8. Should be no more outstanding
    outstanding = await engine.getOutstandingSales(customerId);
    expect(outstanding.isEmpty, isTrue);
  });
}
