import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

/// Service for managing employee leave requests and balances.
class LeaveManagementService {
  final AppDatabase db;

  LeaveManagementService(this.db);

  // ==================== LEAVE TYPES ====================

  Future<List<LeaveType>> getAllLeaveTypes() async {
    return await (db.select(db.leaveTypes)
          ..where((lt) => lt.isActive.equals(true))
          ..orderBy([(lt) => OrderingTerm.asc(lt.name)]))
        .get();
  }

  Future<LeaveType> createLeaveType({
    required String name,
    required String code,
    required int defaultDays,
    bool isPaid = true,
  }) async {
    final id = const Uuid().v4();
    await db.into(db.leaveTypes).insert(
          LeaveTypesCompanion.insert(
            id: Value(id),
            name: name,
            code: code,
            defaultDays: Value(defaultDays),
            isPaid: Value(isPaid),
          ),
        );
    return await (db.select(db.leaveTypes)..where((lt) => lt.id.equals(id)))
        .getSingle();
  }

  // ==================== LEAVE REQUESTS ====================

  Future<LeaveRequest> createLeaveRequest({
    required String employeeId,
    required String leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    required int totalDays,
    String? reason,
  }) async {
    // Check if employee has enough balance
    final balance = await getLeaveBalance(employeeId, leaveTypeId);
    if (balance != null && balance.remaining < totalDays) {
      throw Exception('رصيد الإجازات غير كافي. المتبقي: ${balance.remaining} يوم');
    }

    // Check for overlapping requests
    final overlapping = await (db.select(db.leaveRequests)
          ..where((lr) => lr.employeeId.equals(employeeId))
          ..where((lr) => lr.status.equals('PENDING') | lr.status.equals('APPROVED'))
          ..where((lr) =>
              lr.startDate.isSmallerOrEqualValue(endDate) &
              lr.endDate.isBiggerOrEqualValue(startDate)))
        .get();

    if (overlapping.isNotEmpty) {
      throw Exception('يوجد طلب إجازة متداخل مع هذه الفترة');
    }

    final id = const Uuid().v4();
    await db.into(db.leaveRequests).insert(
          LeaveRequestsCompanion.insert(
            id: Value(id),
            employeeId: employeeId,
            leaveTypeId: leaveTypeId,
            startDate: startDate,
            endDate: endDate,
            totalDays: totalDays,
            reason: Value(reason),
          ),
        );

    return await (db.select(db.leaveRequests)..where((lr) => lr.id.equals(id)))
        .getSingle();
  }

  Future<void> approveLeaveRequest({
    required String requestId,
    required String approvedBy,
    String? note,
  }) async {
    final request = await (db.select(db.leaveRequests)
          ..where((lr) => lr.id.equals(requestId)))
        .getSingleOrNull();

    if (request == null) throw Exception('طلب الإجازة غير موجود');
    if (request.status != 'PENDING') throw Exception('طلب الإجازة ليس في حالة انتظار');

    // Update request status
    await (db.update(db.leaveRequests)..where((lr) => lr.id.equals(requestId)))
        .write(LeaveRequestsCompanion(
      status: const Value('APPROVED'),
      approvedBy: Value(approvedBy),
      approvedAt: Value(DateTime.now()),
    ));

    // Update leave balance
    await _updateLeaveBalance(
      employeeId: request.employeeId,
      leaveTypeId: request.leaveTypeId,
      daysTaken: request.totalDays,
    );
  }

  Future<void> rejectLeaveRequest({
    required String requestId,
    required String rejectedBy,
    required String reason,
  }) async {
    await (db.update(db.leaveRequests)..where((lr) => lr.id.equals(requestId)))
        .write(LeaveRequestsCompanion(
      status: const Value('REJECTED'),
      approvedBy: Value(rejectedBy),
      approvedAt: Value(DateTime.now()),
      rejectionReason: Value(reason),
    ));
  }

  Future<List<LeaveRequest>> getLeaveRequests({
    String? employeeId,
    String? status,
  }) async {
    final query = db.select(db.leaveRequests);
    if (employeeId != null) {
      query.where((lr) => lr.employeeId.equals(employeeId));
    }
    if (status != null) {
      query.where((lr) => lr.status.equals(status));
    }
    query.orderBy([(lr) => OrderingTerm.desc(lr.createdAt)]);
    return await query.get();
  }

  // ==================== LEAVE BALANCES ====================

  Future<LeaveBalance?> getLeaveBalance(String employeeId, String leaveTypeId) async {
    final year = DateTime.now().year;
    return await (db.select(db.leaveBalances)
          ..where((lb) => lb.employeeId.equals(employeeId))
          ..where((lb) => lb.leaveTypeId.equals(leaveTypeId))
          ..where((lb) => lb.year.equals(year)))
        .getSingleOrNull();
  }

  Future<List<LeaveBalance>> getEmployeeBalances(String employeeId) async {
    final year = DateTime.now().year;
    return await (db.select(db.leaveBalances)
          ..where((lb) => lb.employeeId.equals(employeeId))
          ..where((lb) => lb.year.equals(year)))
        .get();
  }

  Future<void> _updateLeaveBalance({
    required String employeeId,
    required String leaveTypeId,
    required int daysTaken,
  }) async {
    final year = DateTime.now().year;
    final existing = await (db.select(db.leaveBalances)
          ..where((lb) => lb.employeeId.equals(employeeId))
          ..where((lb) => lb.leaveTypeId.equals(leaveTypeId))
          ..where((lb) => lb.year.equals(year)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.leaveBalances)
            ..where((lb) => lb.id.equals(existing.id)))
          .write(LeaveBalancesCompanion(
        taken: Value(existing.taken + daysTaken),
        remaining: Value(existing.remaining - daysTaken),
      ));
    } else {
      // Get default days from leave type
      final leaveType = await (db.select(db.leaveTypes)
            ..where((lt) => lt.id.equals(leaveTypeId)))
          .getSingleOrNull();

      final defaultDays = leaveType?.defaultDays ?? 0;
      await db.into(db.leaveBalances).insert(
            LeaveBalancesCompanion.insert(
              employeeId: employeeId,
              leaveTypeId: leaveTypeId,
              year: year,
              entitled: Value(defaultDays),
              taken: Value(daysTaken),
              remaining: Value(defaultDays - daysTaken),
            ),
          );
    }
  }
}
