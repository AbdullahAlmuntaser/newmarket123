import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

/// Service for tracking employee attendance and overtime.
class AttendanceService {
  final AppDatabase db;

  AttendanceService(this.db);

  /// Clock in an employee
  Future<AttendanceRecord> clockIn({
    required String employeeId,
    String? notes,
  }) async {
    // Check if already clocked in today
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final existing = await (db.select(db.attendanceRecords)
          ..where((ar) => ar.employeeId.equals(employeeId))
          ..where((ar) => ar.clockIn.isBiggerOrEqualValue(startOfDay))
          ..where((ar) => ar.clockIn.isSmallerThanValue(endOfDay)))
        .getSingleOrNull();

    if (existing != null) {
      throw Exception('تم تسجيل حضور هذا الموظف بالفعل اليوم');
    }

    // Determine status (LATE if after 9:00 AM)
    String status = 'PRESENT';
    if (today.hour > 9 || (today.hour == 9 && today.minute > 0)) {
      status = 'LATE';
    }

    final id = const Uuid().v4();
    await db.into(db.attendanceRecords).insert(
          AttendanceRecordsCompanion.insert(
            id: Value(id),
            employeeId: employeeId,
            clockIn: today,
            status: Value(status),
            notes: Value(notes),
          ),
        );

    return await (db.select(db.attendanceRecords)
          ..where((ar) => ar.id.equals(id)))
        .getSingle();
  }

  /// Clock out an employee
  Future<AttendanceRecord> clockOut({
    required String employeeId,
    String? notes,
  }) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final record = await (db.select(db.attendanceRecords)
          ..where((ar) => ar.employeeId.equals(employeeId))
          ..where((ar) => ar.clockIn.isBiggerOrEqualValue(startOfDay))
          ..where((ar) => ar.clockIn.isSmallerThanValue(endOfDay)))
        .getSingleOrNull();

    if (record == null) {
      throw Exception('لم يتم تسجيل حضور هذا الموظف اليوم');
    }

    if (record.clockOut != null) {
      throw Exception('تم تسجيل انصراف هذا الموظف بالفعل');
    }

    // Calculate overtime if clock out after 5 PM
    Decimal overtimeHours = Decimal.zero;
    if (today.hour > 17 || (today.hour == 17 && today.minute > 0)) {
      overtimeHours = Decimal.parse(
          ((today.hour - 17) + today.minute / 60.0).toStringAsFixed(2));
    }

    // Determine if early leave (before 5 PM)
    String status = record.status;
    if (today.hour < 17 && status != 'ON_LEAVE') {
      status = 'EARLY_LEAVE';
    }

    await (db.update(db.attendanceRecords)
          ..where((ar) => ar.id.equals(record.id)))
        .write(AttendanceRecordsCompanion(
      clockOut: Value(today),
      status: Value(status),
      overtimeHours: Value(overtimeHours),
      notes: Value(notes ?? record.notes),
    ));

    return await (db.select(db.attendanceRecords)
          ..where((ar) => ar.id.equals(record.id)))
        .getSingle();
  }

  /// Get attendance records for an employee in a date range
  Future<List<AttendanceRecord>> getEmployeeAttendance({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = db.select(db.attendanceRecords)
      ..where((ar) => ar.employeeId.equals(employeeId));

    if (startDate != null) {
      query.where((ar) => ar.clockIn.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((ar) => ar.clockIn.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(ar) => OrderingTerm.desc(ar.clockIn)]);
    return await query.get();
  }

  /// Get attendance summary for a period
  Future<AttendanceSummary> getAttendanceSummary({
    required String employeeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final records = await getEmployeeAttendance(
      employeeId: employeeId,
      startDate: startDate,
      endDate: endDate,
    );

    int presentDays = 0;
    int absentDays = 0;
    int lateDays = 0;
    int earlyLeaveDays = 0;
    int onLeaveDays = 0;
    Decimal totalOvertime = Decimal.zero;

    for (final record in records) {
      switch (record.status) {
        case 'PRESENT':
          presentDays++;
          break;
        case 'ABSENT':
          absentDays++;
          break;
        case 'LATE':
          lateDays++;
          break;
        case 'EARLY_LEAVE':
          earlyLeaveDays++;
          break;
        case 'ON_LEAVE':
          onLeaveDays++;
          break;
      }
      totalOvertime += record.overtimeHours;
    }

    return AttendanceSummary(
      employeeId: employeeId,
      periodStart: startDate,
      periodEnd: endDate,
      presentDays: presentDays,
      absentDays: absentDays,
      lateDays: lateDays,
      earlyLeaveDays: earlyLeaveDays,
      onLeaveDays: onLeaveDays,
      totalOvertimeHours: totalOvertime,
    );
  }

  /// Mark an employee as on leave (for a specific date)
  Future<void> markOnLeave({
    required String employeeId,
    required DateTime date,
    String? notes,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Check if already has a record
    final existing = await (db.select(db.attendanceRecords)
          ..where((ar) => ar.employeeId.equals(employeeId))
          ..where((ar) => ar.clockIn.isBiggerOrEqualValue(startOfDay))
          ..where((ar) => ar.clockIn.isSmallerThanValue(endOfDay)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.attendanceRecords)
            ..where((ar) => ar.id.equals(existing.id)))
          .write(AttendanceRecordsCompanion(
        status: const Value('ON_LEAVE'),
        notes: Value(notes),
      ));
    } else {
      await db.into(db.attendanceRecords).insert(
            AttendanceRecordsCompanion.insert(
              employeeId: employeeId,
              clockIn: startOfDay,
              status: const Value('ON_LEAVE'),
              notes: Value(notes),
            ),
          );
    }
  }
}

/// Attendance summary data class
class AttendanceSummary {
  final String employeeId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int earlyLeaveDays;
  final int onLeaveDays;
  final Decimal totalOvertimeHours;

  const AttendanceSummary({
    required this.employeeId,
    required this.periodStart,
    required this.periodEnd,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.earlyLeaveDays,
    required this.onLeaveDays,
    required this.totalOvertimeHours,
  });
}
