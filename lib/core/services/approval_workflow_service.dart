import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:supermarket/core/services/app_config_service.dart';

class ApprovalStatus {
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

class ApprovalRequest {
  const ApprovalRequest({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.requestedBy,
    required this.createdAt,
    required this.status,
    this.referenceId,
    this.note,
    this.decidedBy,
    this.decidedAt,
    this.decisionNote,
  });

  final String id;
  final String type;
  final String title;
  final double amount;
  final String requestedBy;
  final DateTime createdAt;
  final String status;
  final String? referenceId;
  final String? note;
  final String? decidedBy;
  final DateTime? decidedAt;
  final String? decisionNote;

  bool get isPending => status == ApprovalStatus.pending;

  ApprovalRequest copyWith({
    String? status,
    String? decidedBy,
    DateTime? decidedAt,
    String? decisionNote,
  }) {
    return ApprovalRequest(
      id: id,
      type: type,
      title: title,
      amount: amount,
      requestedBy: requestedBy,
      createdAt: createdAt,
      status: status ?? this.status,
      referenceId: referenceId,
      note: note,
      decidedBy: decidedBy ?? this.decidedBy,
      decidedAt: decidedAt ?? this.decidedAt,
      decisionNote: decisionNote ?? this.decisionNote,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'amount': amount,
      'requestedBy': requestedBy,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'referenceId': referenceId,
      'note': note,
      'decidedBy': decidedBy,
      'decidedAt': decidedAt?.toIso8601String(),
      'decisionNote': decisionNote,
    };
  }

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      requestedBy: json['requestedBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: json['status'] as String,
      referenceId: json['referenceId'] as String?,
      note: json['note'] as String?,
      decidedBy: json['decidedBy'] as String?,
      decidedAt: json['decidedAt'] == null
          ? null
          : DateTime.parse(json['decidedAt'] as String),
      decisionNote: json['decisionNote'] as String?,
    );
  }
}

class ApprovalWorkflowService {
  ApprovalWorkflowService(this._configService);

  static const String keyApprovalRequests = 'approval_requests_json';
  static const double defaultPurchaseApprovalThreshold = 10000;

  final AppConfigService _configService;

  Future<bool> requiresApproval({
    required String type,
    required double amount,
    double? threshold,
  }) async {
    return amount >= (threshold ?? defaultPurchaseApprovalThreshold);
  }

  Future<ApprovalRequest> createRequest({
    required String type,
    required String title,
    required double amount,
    required String requestedBy,
    String? referenceId,
    String? note,
  }) async {
    final requests = await listRequests();
    final request = ApprovalRequest(
      id: const Uuid().v4(),
      type: type,
      title: title,
      amount: amount,
      requestedBy: requestedBy,
      createdAt: DateTime.now(),
      status: ApprovalStatus.pending,
      referenceId: referenceId,
      note: note,
    );
    requests.insert(0, request);
    await _saveRequests(requests);
    return request;
  }

  Future<List<ApprovalRequest>> listRequests({String? status}) async {
    final raw = await _configService.getString(keyApprovalRequests);
    if (raw == null || raw.trim().isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    final requests = decoded
        .map((item) => ApprovalRequest.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (status == null) return requests;
    return requests.where((request) => request.status == status).toList();
  }

  Future<void> approve({
    required String requestId,
    required String decidedBy,
    String? decisionNote,
  }) async {
    await _decide(
      requestId: requestId,
      status: ApprovalStatus.approved,
      decidedBy: decidedBy,
      decisionNote: decisionNote,
    );
  }

  Future<void> reject({
    required String requestId,
    required String decidedBy,
    String? decisionNote,
  }) async {
    await _decide(
      requestId: requestId,
      status: ApprovalStatus.rejected,
      decidedBy: decidedBy,
      decisionNote: decisionNote,
    );
  }

  Future<void> _decide({
    required String requestId,
    required String status,
    required String decidedBy,
    String? decisionNote,
  }) async {
    final requests = await listRequests();
    final index = requests.indexWhere((request) => request.id == requestId);
    if (index == -1) {
      throw Exception('Approval request not found');
    }
    if (!requests[index].isPending) {
      throw Exception('Approval request already decided');
    }

    requests[index] = requests[index].copyWith(
      status: status,
      decidedBy: decidedBy,
      decidedAt: DateTime.now(),
      decisionNote: decisionNote,
    );
    await _saveRequests(requests);
  }

  Future<void> _saveRequests(List<ApprovalRequest> requests) async {
    final encoded = jsonEncode(
      requests.map((request) => request.toJson()).toList(),
    );
    await _configService.setString(keyApprovalRequests, encoded);
  }
}
