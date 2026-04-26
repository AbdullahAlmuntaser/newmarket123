import 'package:drift/drift.dart';
import '../app_database.dart';

part 'audit_dao.g.dart';

@DriftAccessor(tables: [AuditLogs])
class AuditDao extends DatabaseAccessor<AppDatabase> with _$AuditDaoMixin {
  AuditDao(super.db);

  Future<int> insertLog(AuditLogsCompanion entry) =>
      into(auditLogs).insert(entry);
}
