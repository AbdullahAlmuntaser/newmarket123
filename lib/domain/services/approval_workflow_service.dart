import 'package:sqflite/sqflite.dart';

class ApprovalWorkflowService {
  final Database database;

  ApprovalWorkflowService({required this.database});

  /// Check if document requires approval
  Future<bool> requiresApproval({
    required String documentType,
    required double amount,
  }) async {
    final workflows = await database.query(
      'approval_workflows',
      where: 'document_type = ? AND is_active = 1',
      whereArgs: [documentType],
    );

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

  /// Create approval request
  Future<int> createApprovalRequest({
    required String documentType,
    required int documentId,
    required int requestedBy,
  }) async {
    // Find applicable workflow
    final workflows = await database.query(
      'approval_workflows',
      where: 'document_type = ? AND is_active = 1',
      whereArgs: [documentType],
      orderBy: 'level_order ASC',
    );

    if (workflows.isEmpty) {
      throw Exception('No active workflow found for document type: $documentType');
    }

    final workflowId = workflows.first['id'] as int;

    // Create approval request
    final requestId = await database.insert('approval_requests', {
      'document_type': documentType,
      'document_id': documentId,
      'workflow_id': workflowId,
      'current_level': 1,
      'status': 'pending',
      'requested_by': requestedBy,
    });

    return requestId;
  }

  /// Get approval levels for a workflow
  Future<List<Map<String, dynamic>>> getApprovalLevels(int workflowId) async {
    return await database.query(
      'approval_levels',
      where: 'workflow_id = ?',
      whereArgs: [workflowId],
      orderBy: 'level_order ASC',
    );
  }

  /// Approve or reject request
  Future<void> processApproval({
    required int requestId,
    required int approverId,
    required String action,
    String? comments,
  }) async {
    await database.transaction((txn) async {
      // Get current request
      final requests = await txn.query(
        'approval_requests',
        where: 'id = ?',
        whereArgs: [requestId],
      );

      if (requests.isEmpty) {
        throw Exception('Approval request not found');
      }

      final request = requests.first;
      final currentLevel = request['current_level'] as int;
      final workflowId = request['workflow_id'] as int;

      // Get approver info
      final approverInfo = await txn.query(
        'approval_levels',
        where: 'workflow_id = ? AND level_order = ?',
        whereArgs: [workflowId, currentLevel],
      );

      final roleId = approverInfo.isNotEmpty ? approverInfo.first['role_id'] : null;

      // Record approval history
      await txn.insert('approval_history', {
        'request_id': requestId,
        'level_order': currentLevel,
        'approver_id': approverId,
        'approver_role_id': roleId,
        'action': action,
        'comments': comments,
      });

      if (action == 'approved') {
        // Check if there are more levels
        final nextLevels = await txn.query(
          'approval_levels',
          where: 'workflow_id = ? AND level_order > ?',
          whereArgs: [workflowId, currentLevel],
          orderBy: 'level_order ASC',
          limit: 1,
        );

        if (nextLevels.isNotEmpty) {
          // Move to next level
          await txn.update(
            'approval_requests',
            {'current_level': currentLevel + 1},
            where: 'id = ?',
            whereArgs: [requestId],
          );
        } else {
          // All levels approved
          await txn.update(
            'approval_requests',
            {
              'status': 'approved',
              'completed_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [requestId],
          );
        }
      } else if (action == 'rejected') {
        // Reject the request
        await txn.update(
          'approval_requests',
          {
            'status': 'rejected',
            'completed_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [requestId],
        );
      }
    });
  }

  /// Get pending approvals for a user
  Future<List<Map<String, dynamic>>> getPendingApprovalsForUser({
    required int userId,
    String? documentType,
  }) async {
    String whereClause = 'status = ?';
    List<dynamic> whereArgs = ['pending'];

    if (documentType != null) {
      whereClause += ' AND document_type = ?';
      whereArgs.add(documentType);
    }

    // Get user's role
    final userRoles = await database.query(
      'user_roles',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (userRoles.isEmpty) {
      return [];
    }

    final roleIds = userRoles.map((r) => r['role_id']).toList();

    // Get pending requests where user's role is the current approver
    final pendingRequests = await database.query(
      'approval_requests',
      where: whereClause,
      whereArgs: whereArgs,
    );

    List<Map<String, dynamic>> filteredRequests = [];

    for (var request in pendingRequests) {
      final workflowId = request['workflow_id'] as int;
      final currentLevel = request['current_level'] as int;

      final levels = await database.query(
        'approval_levels',
        where: 'workflow_id = ? AND level_order = ?',
        whereArgs: [workflowId, currentLevel],
      );

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
