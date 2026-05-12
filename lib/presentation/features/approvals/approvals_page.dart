import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/services/approval_workflow_service.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  bool _isLoading = true;
  List<ApprovalRequest> _requests = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRequests());
  }

  ApprovalWorkflowService get _service => context.read<ApprovalWorkflowService>();

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _service.listRequests();
      if (mounted) {
        setState(() => _requests = requests);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل طلبات الموافقة: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createDemoRequest() async {
    final auth = context.read<AuthProvider>();
    await _service.createRequest(
      type: 'purchase',
      title: 'طلب موافقة شراء كبير',
      amount: ApprovalWorkflowService.defaultPurchaseApprovalThreshold,
      requestedBy: auth.currentUser?.username ?? 'system',
      note: 'طلب تجريبي لتفعيل سير الموافقات حتى يتم ربطه بنماذج المشتريات.',
    );
    await _loadRequests();
  }

  Future<void> _decide(ApprovalRequest request, bool approved) async {
    final auth = context.read<AuthProvider>();
    final decidedBy = auth.currentUser?.username ?? 'system';
    try {
      if (approved) {
        await _service.approve(requestId: request.id, decidedBy: decidedBy);
      } else {
        await _service.reject(requestId: request.id, decidedBy: decidedBy);
      }
      await _loadRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approved ? 'تمت الموافقة' : 'تم الرفض')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث طلب الموافقة: $e')),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case ApprovalStatus.approved:
        return Colors.green;
      case ApprovalStatus.rejected:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case ApprovalStatus.approved:
        return 'موافق عليه';
      case ApprovalStatus.rejected:
        return 'مرفوض';
      default:
        return 'قيد الانتظار';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سير الموافقات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _isLoading ? null : _loadRequests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDemoRequest,
        icon: const Icon(Icons.add_task),
        label: const Text('طلب تجريبي'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: _requests.isEmpty
                  ? const ListView(
                      children: [
                        SizedBox(height: 160),
                        Center(child: Text('لا توجد طلبات موافقة حالياً')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        final request = _requests[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(request.status),
                              child: const Icon(Icons.rule, color: Colors.white),
                            ),
                            title: Text(request.title),
                            subtitle: Text(
                              '${request.type} • ${NumberFormat.currency(symbol: '').format(request.amount)}\n'
                              'بواسطة ${request.requestedBy} • ${DateFormat('yyyy-MM-dd HH:mm').format(request.createdAt)}\n'
                              '${request.note ?? ''}',
                            ),
                            isThreeLine: true,
                            trailing: request.isPending
                                ? Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                        tooltip: 'موافقة',
                                        onPressed: () => _decide(request, true),
                                        icon: const Icon(Icons.check_circle),
                                        color: Colors.green,
                                      ),
                                      IconButton(
                                        tooltip: 'رفض',
                                        onPressed: () => _decide(request, false),
                                        icon: const Icon(Icons.cancel),
                                        color: Colors.red,
                                      ),
                                    ],
                                  )
                                : Chip(
                                    label: Text(_statusLabel(request.status)),
                                    backgroundColor:
                                        _statusColor(request.status).withOpacity(0.12),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
