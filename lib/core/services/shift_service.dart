import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

class ShiftService {
  final AppDatabase db;

  ShiftService(this.db);

  Future<Shift?> getActiveShift(String userId) async {
    return await (db.select(db.shifts)
          ..where((t) => t.userId.equals(userId) & t.isOpen.equals(true))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> openShift(
    String userId,
    double openingCash, {
    String? note,
  }) async {
    final activeShift = await getActiveShift(userId);
    if (activeShift != null) {
      throw Exception('There is already an active shift for this user.');
    }

    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion.insert(
            id: Value(const Uuid().v4()),
            userId: userId,
            openingCash: Value(openingCash),
            startTime: Value(DateTime.now()),
            isOpen: const Value(true),
            note: Value(note),
          ),
        );
  }

  Future<double> calculateExpectedCash(Shift shift) async {
    final startTime = shift.startTime;
    final endTime = shift.endTime ?? DateTime.now();

    // Get all cash sales during the shift
    final cashSales =
        await (db.select(db.sales)..where(
              (t) =>
                  t.createdAt.isBiggerOrEqualValue(startTime) &
                  t.createdAt.isSmallerOrEqualValue(endTime) &
                  t.paymentMethod.equals('cash'),
            ))
            .get();
    final totalCashSales = cashSales.fold(0.0, (sum, sale) => sum + sale.total);

    // Get all customer cash payments during the shift
    final customerPayments =
        await (db.select(db.customerPayments)..where(
              (t) =>
                  t.paymentDate.isBiggerOrEqualValue(startTime) &
                  t.paymentDate.isSmallerOrEqualValue(endTime),
            ))
            .get();
    final totalCustomerPayments = customerPayments.fold(
      0.0,
      (sum, p) => sum + p.amount,
    );

    // Get all supplier cash payments (expenses) during the shift
    final supplierPayments =
        await (db.select(db.supplierPayments)..where(
              (t) =>
                  t.paymentDate.isBiggerOrEqualValue(startTime) &
                  t.paymentDate.isSmallerOrEqualValue(endTime),
            ))
            .get();
    final totalSupplierPayments = supplierPayments.fold(
      0.0,
      (sum, p) => sum + p.amount,
    );

    return shift.openingCash +
        totalCashSales +
        totalCustomerPayments -
        totalSupplierPayments;
  }

  Future<void> closeShift(
    String shiftId,
    double closingCash, {
    String? note,
  }) async {
    final shift = await (db.select(
      db.shifts,
    )..where((t) => t.id.equals(shiftId))).getSingle();
    final expectedCash = await calculateExpectedCash(shift);

    await (db.update(db.shifts)..where((t) => t.id.equals(shiftId))).write(
      ShiftsCompanion(
        endTime: Value(DateTime.now()),
        closingCash: Value(closingCash),
        expectedCash: Value(expectedCash),
        isOpen: const Value(false),
        note: Value(note),
      ),
    );
  }
}
