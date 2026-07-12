import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class ApprovalWorkflowService {
  final AppDatabase database;

  ApprovalWorkflowService({required this.database});

  Future<bool> requiresApproval({
    required String documentType,
    required double amount,
  }) async {
    final workflows = (await database.customSelect(
      'SELECT * FROM approval_workflows WHERE document_type = ? AND is_active = 1',
      variables: [Variable(documentType)],
    ).get()).map((e) => e.data).toList();

    for (var workflow in workflows) {
      final conditionType = workflow['condition_type'] as String?;
      final conditionValue = workflow['condition_value'] as num?;
      final operator = workflow['operator'] as String?;

      if (conditionType == 'amount' && conditionValue != null) {
        bool conditionMet = false;
        switch (operator) {
          case '>':
            conditionMet = amount > conditionValue;
            break;
          case '<':
            conditionMet = amount < conditionValue;
            break;
          case '>=':
            conditionMet = amount >= conditionValue;
            break;
          case '<=':
            conditionMet = amount <= conditionValue;
            break;
          case '=':
            conditionMet = amount == conditionValue;
            break;
        }

        if (conditionMet) {
          return true;
        }
      }
    }

    return false;
  }

  Future<int> createApprovalRequest({
    required String documentType,
    required int documentId,
    required int requestedBy,
  }) async {
    final workflows = (await database.customSelect(
      'SELECT * FROM approval_workflows WHERE document_type = ? AND is_active = 1 ORDER BY level_order ASC',
      variables: [Variable(documentType)],
    ).get()).map((e) => e.data).toList();

    if (workflows.isEmpty) {
      throw Exception('No active workflow found for document type: $documentType');
    }

    final workflowId = workflows.first['id'] as int;

    final requestId = await database.customInsert(
      'INSERT INTO approval_requests (document_type, document_id, workflow_id, current_level, status, requested_by) VALUES (?, ?, ?, 1, \'pending\', ?)',
      variables: [Variable(documentType), Variable(documentId), Variable(workflowId), Variable(requestedBy)],
    );

    return requestId;
  }

  Future<List<Map<String, dynamic>>> getApprovalLevels(int workflowId) async {
    return (await database.customSelect(
      'SELECT * FROM approval_levels WHERE workflow_id = ? ORDER BY level_order ASC',
      variables: [Variable(workflowId)],
    ).get()).map((e) => e.data).toList();
  }

  Future<void> processApproval({
    required int requestId,
    required int approverId,
    required String action,
    String? comments,
  }) async {
    await database.transaction(() async {
      final requests = (await database.customSelect(
        'SELECT * FROM approval_requests WHERE id = ?',
        variables: [Variable(requestId)],
      ).get()).map((e) => e.data).toList();

      if (requests.isEmpty) {
        throw Exception('Approval request not found');
      }

      final request = requests.first;
      final currentLevel = request['current_level'] as int;
      final workflowId = request['workflow_id'] as int;

      final approverInfo = (await database.customSelect(
        'SELECT * FROM approval_levels WHERE workflow_id = ? AND level_order = ?',
        variables: [Variable(workflowId), Variable(currentLevel)],
      ).get()).map((e) => e.data).toList();

      final roleId = approverInfo.isNotEmpty ? approverInfo.first['role_id'] : null;

      await database.customInsert(
        'INSERT INTO approval_history (request_id, level_order, approver_id, approver_role_id, action, comments) VALUES (?, ?, ?, ?, ?, ?)',
        variables: [Variable(requestId), Variable(currentLevel), Variable(approverId), Variable(roleId as Object), Variable(action), Variable(comments)],
      );

      if (action == 'approved') {
        final nextLevels = (await database.customSelect(
          'SELECT * FROM approval_levels WHERE workflow_id = ? AND level_order > ? ORDER BY level_order ASC LIMIT 1',
          variables: [Variable(workflowId), Variable(currentLevel)],
        ).get()).map((e) => e.data).toList();

        if (nextLevels.isNotEmpty) {
          await database.customUpdate(
            'UPDATE approval_requests SET current_level = ? WHERE id = ?',
            variables: [Variable(currentLevel + 1), Variable(requestId)],
          );
        } else {
          await database.customUpdate(
            "UPDATE approval_requests SET status = 'approved', completed_at = ? WHERE id = ?",
            variables: [Variable(DateTime.now().toIso8601String()), Variable(requestId)],
          );
        }
      } else if (action == 'rejected') {
        await database.customUpdate(
          "UPDATE approval_requests SET status = 'rejected', completed_at = ? WHERE id = ?",
          variables: [Variable(DateTime.now().toIso8601String()), Variable(requestId)],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getPendingApprovalsForUser({
    required int userId,
    String? documentType,
  }) async {
    String whereClause = "status = 'pending'";
    List<Variable> docVars = [];

    if (documentType != null) {
      whereClause += ' AND document_type = ?';
      docVars = [Variable(documentType)];
    }

    final userRoles = (await database.customSelect(
      'SELECT * FROM user_roles WHERE user_id = ?',
      variables: [Variable(userId)],
    ).get()).map((e) => e.data).toList();

    if (userRoles.isEmpty) {
      return [];
    }

    final roleIds = userRoles.map((r) => r['role_id']).toList();

    final pendingRequests = (await database.customSelect(
      'SELECT * FROM approval_requests WHERE $whereClause',
      variables: docVars,
    ).get()).map((e) => e.data).toList();

    List<Map<String, dynamic>> filteredRequests = [];

    for (var request in pendingRequests) {
      final workflowId = request['workflow_id'] as int;
      final currentLevel = request['current_level'] as int;

      final levels = (await database.customSelect(
        'SELECT * FROM approval_levels WHERE workflow_id = ? AND level_order = ?',
        variables: [Variable(workflowId), Variable(currentLevel)],
      ).get()).map((e) => e.data).toList();

      for (var level in levels) {
        final roleId = level['role_id'];
        if (roleId != null && roleIds.contains(roleId)) {
          filteredRequests.add(request);
          break;
        }
      }
    }

    return filteredRequests;
  }
}
