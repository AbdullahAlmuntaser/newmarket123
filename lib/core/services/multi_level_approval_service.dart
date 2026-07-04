import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:supermarket/core/services/app_config_service.dart';

/// Multi-level approval chain configuration and execution.
/// Supports conditional routing based on amount thresholds.
class MultiLevelApprovalService {
  MultiLevelApprovalService(this._configService);

  static const String keyApprovalChains = 'approval_chains_json';
  static const String keyApprovalChainInstances = 'approval_chain_instances_json';

  final AppConfigService _configService;

  /// Create an approval chain definition
  Future<ApprovalChain> createChain({
    required String name,
    required String type, // PURCHASE, EXPENSE, PAYMENT
    required List<ApprovalChainLevel> levels,
  }) async {
    final chains = await listChains();
    final chain = ApprovalChain(
      id: const Uuid().v4(),
      name: name,
      type: type,
      levels: levels,
      isActive: true,
      createdAt: DateTime.now(),
    );

    chains.add(chain);
    await _saveChains(chains);
    return chain;
  }

  /// Get all approval chains
  Future<List<ApprovalChain>> listChains({String? type}) async {
    final raw = await _configService.getString(keyApprovalChains);
    if (raw == null || raw.trim().isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    final chains = decoded
        .map((item) => ApprovalChain.fromJson(item as Map<String, dynamic>))
        .toList();

    if (type == null) return chains;
    return chains.where((c) => c.type == type).toList();
  }

  /// Start an approval chain for a transaction
  Future<ApprovalChainInstance> startChain({
    required String chainId,
    required String referenceType,
    required String referenceId,
    required double amount,
    required String requestedBy,
  }) async {
    final chains = await listChains();
    final chain = chains.firstWhere(
      (c) => c.id == chainId,
      orElse: () => throw Exception('سلسلة الموافقات غير موجودة'),
    );

    // Determine which level based on amount
    int startLevel = 0;
    for (int i = chain.levels.length - 1; i >= 0; i--) {
      if (amount >= chain.levels[i].minAmount) {
        startLevel = i;
        break;
      }
    }

    final instance = ApprovalChainInstance(
      id: const Uuid().v4(),
      chainId: chainId,
      referenceType: referenceType,
      referenceId: referenceId,
      amount: amount,
      requestedBy: requestedBy,
      currentLevel: startLevel,
      status: 'PENDING',
      createdAt: DateTime.now(),
      levelDecisions: [],
    );

    final instances = await _listInstances();
    instances.insert(0, instance);
    await _saveInstances(instances);

    return instance;
  }

  /// Approve at current level
  Future<void> approveLevel({
    required String instanceId,
    required String decidedBy,
    String? decisionNote,
  }) async {
    final instances = await _listInstances();
    final index = instances.indexWhere((i) => i.id == instanceId);

    if (index == -1) throw Exception('سلسلة الموافقات غير موجودة');

    final instance = instances[index];
    if (instance.status != 'PENDING') throw Exception('سلسلة الموافقات غير في حالة انتظار');

    final chains = await listChains();
    final chain = chains.firstWhere((c) => c.id == instance.chainId);

    // Record decision
    final decision = LevelDecision(
      level: instance.currentLevel,
      levelName: chain.levels[instance.currentLevel].name,
      decidedBy: decidedBy,
      decision: 'APPROVED',
      decisionNote: decisionNote,
      decidedAt: DateTime.now(),
    );

    final updatedDecisions = List<LevelDecision>.from(instance.levelDecisions)
      ..add(decision);

    // Check if there are more levels
    if (instance.currentLevel < chain.levels.length - 1) {
      // Move to next level
      instances[index] = instance.copyWith(
        currentLevel: instance.currentLevel + 1,
        levelDecisions: updatedDecisions,
      );
    } else {
      // All levels approved
      instances[index] = instance.copyWith(
        status: 'APPROVED',
        levelDecisions: updatedDecisions,
        completedAt: DateTime.now(),
      );
    }

    await _saveInstances(instances);
  }

  /// Reject at current level
  Future<void> rejectLevel({
    required String instanceId,
    required String decidedBy,
    required String decisionNote,
  }) async {
    final instances = await _listInstances();
    final index = instances.indexWhere((i) => i.id == instanceId);

    if (index == -1) throw Exception('سلسلة الموافقات غير موجودة');

    final instance = instances[index];
    if (instance.status != 'PENDING') throw Exception('سلسلة الموافقات غير في حالة انتظار');

    final chains = await listChains();
    final chain = chains.firstWhere((c) => c.id == instance.chainId);

    final decision = LevelDecision(
      level: instance.currentLevel,
      levelName: chain.levels[instance.currentLevel].name,
      decidedBy: decidedBy,
      decision: 'REJECTED',
      decisionNote: decisionNote,
      decidedAt: DateTime.now(),
    );

    final updatedDecisions = List<LevelDecision>.from(instance.levelDecisions)
      ..add(decision);

    instances[index] = instance.copyWith(
      status: 'REJECTED',
      levelDecisions: updatedDecisions,
      completedAt: DateTime.now(),
    );

    await _saveInstances(instances);
  }

  /// Get pending approvals for a user
  Future<List<ApprovalChainInstance>> getPendingApprovals({
    String? referenceType,
  }) async {
    final instances = await _listInstances();
    final pending = instances.where((i) => i.status == 'PENDING').toList();

    if (referenceType != null) {
      return pending.where((i) => i.referenceType == referenceType).toList();
    }

    return pending;
  }

  /// Get chain instance for a reference
  Future<ApprovalChainInstance?> getInstanceForReference({
    required String referenceType,
    required String referenceId,
  }) async {
    final instances = await _listInstances();
    try {
      return instances.firstWhere(
        (i) => i.referenceType == referenceType && i.referenceId == referenceId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveChains(List<ApprovalChain> chains) async {
    final encoded = jsonEncode(chains.map((c) => c.toJson()).toList());
    await _configService.setString(keyApprovalChains, encoded);
  }

  Future<List<ApprovalChainInstance>> _listInstances() async {
    final raw = await _configService.getString(keyApprovalChainInstances);
    if (raw == null || raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => ApprovalChainInstance.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveInstances(List<ApprovalChainInstance> instances) async {
    final encoded = jsonEncode(instances.map((i) => i.toJson()).toList());
    await _configService.setString(keyApprovalChainInstances, encoded);
  }
}

// ==================== DATA CLASSES ====================

class ApprovalChain {
  final String id;
  final String name;
  final String type;
  final List<ApprovalChainLevel> levels;
  final bool isActive;
  final DateTime createdAt;

  const ApprovalChain({
    required this.id,
    required this.name,
    required this.type,
    required this.levels,
    required this.isActive,
    required this.createdAt,
  });

  factory ApprovalChain.fromJson(Map<String, dynamic> json) {
    return ApprovalChain(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      levels: (json['levels'] as List<dynamic>)
          .map((l) => ApprovalChainLevel.fromJson(l as Map<String, dynamic>))
          .toList(),
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'levels': levels.map((l) => l.toJson()).toList(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class ApprovalChainLevel {
  final int level;
  final String name;
  final String approverRole;
  final double minAmount;

  const ApprovalChainLevel({
    required this.level,
    required this.name,
    required this.approverRole,
    required this.minAmount,
  });

  factory ApprovalChainLevel.fromJson(Map<String, dynamic> json) {
    return ApprovalChainLevel(
      level: json['level'] as int,
      name: json['name'] as String,
      approverRole: json['approverRole'] as String,
      minAmount: (json['minAmount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'name': name,
      'approverRole': approverRole,
      'minAmount': minAmount,
    };
  }
}

class ApprovalChainInstance {
  final String id;
  final String chainId;
  final String referenceType;
  final String referenceId;
  final double amount;
  final String requestedBy;
  final int currentLevel;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<LevelDecision> levelDecisions;

  const ApprovalChainInstance({
    required this.id,
    required this.chainId,
    required this.referenceType,
    required this.referenceId,
    required this.amount,
    required this.requestedBy,
    required this.currentLevel,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.levelDecisions,
  });

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  ApprovalChainInstance copyWith({
    int? currentLevel,
    String? status,
    DateTime? completedAt,
    List<LevelDecision>? levelDecisions,
  }) {
    return ApprovalChainInstance(
      id: id,
      chainId: chainId,
      referenceType: referenceType,
      referenceId: referenceId,
      amount: amount,
      requestedBy: requestedBy,
      currentLevel: currentLevel ?? this.currentLevel,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      levelDecisions: levelDecisions ?? this.levelDecisions,
    );
  }

  factory ApprovalChainInstance.fromJson(Map<String, dynamic> json) {
    return ApprovalChainInstance(
      id: json['id'] as String,
      chainId: json['chainId'] as String,
      referenceType: json['referenceType'] as String,
      referenceId: json['referenceId'] as String,
      amount: (json['amount'] as num).toDouble(),
      requestedBy: json['requestedBy'] as String,
      currentLevel: json['currentLevel'] as int,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      levelDecisions: (json['levelDecisions'] as List<dynamic>)
          .map((d) => LevelDecision.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chainId': chainId,
      'referenceType': referenceType,
      'referenceId': referenceId,
      'amount': amount,
      'requestedBy': requestedBy,
      'currentLevel': currentLevel,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'levelDecisions': levelDecisions.map((d) => d.toJson()).toList(),
    };
  }
}

class LevelDecision {
  final int level;
  final String levelName;
  final String decidedBy;
  final String decision;
  final String? decisionNote;
  final DateTime decidedAt;

  const LevelDecision({
    required this.level,
    required this.levelName,
    required this.decidedBy,
    required this.decision,
    this.decisionNote,
    required this.decidedAt,
  });

  factory LevelDecision.fromJson(Map<String, dynamic> json) {
    return LevelDecision(
      level: json['level'] as int,
      levelName: json['levelName'] as String,
      decidedBy: json['decidedBy'] as String,
      decision: json['decision'] as String,
      decisionNote: json['decisionNote'] as String?,
      decidedAt: DateTime.parse(json['decidedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'levelName': levelName,
      'decidedBy': decidedBy,
      'decision': decision,
      'decisionNote': decisionNote,
      'decidedAt': decidedAt.toIso8601String(),
    };
  }
}
