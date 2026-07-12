import 'package:get_it/get_it.dart';
import 'package:supermarket/core/services/hr_service.dart';
import 'package:supermarket/core/services/attendance_service.dart';
import 'package:supermarket/core/services/leave_management_service.dart';
import 'package:supermarket/core/services/payroll_service.dart';
import 'package:supermarket/core/services/shift_service.dart';
import 'package:supermarket/core/services/auto_break_service.dart';
import 'package:supermarket/core/services/eosb_service.dart';
import 'package:supermarket/core/services/packaging_engine.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

void registerHRModule(GetIt sl) {
  final db = sl<AppDatabase>();

  sl.registerLazySingleton<HRService>(() => HRService(db));
  sl.registerLazySingleton<AttendanceService>(
    () => AttendanceService(db),
  );
  sl.registerLazySingleton<LeaveManagementService>(
    () => LeaveManagementService(db),
  );
  sl.registerLazySingleton<PayrollService>(() => PayrollService(db));
  sl.registerLazySingleton<ShiftService>(() => ShiftService(db));
  sl.registerLazySingleton<EndOfServiceBenefitService>(() => EndOfServiceBenefitService(db));
  sl.registerLazySingleton<AutoBreakService>(
    () => AutoBreakService(db, sl<PackagingEngine>()),
  );
}
