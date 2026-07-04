import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/presentation/features/hr/leave_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';
import 'package:intl/intl.dart' as intl;

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LeaveProvider>();
      provider.loadLeaveTypes();
      provider.loadLeaveRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeaveProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الإجازات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'أنواع الإجازات'),
            Tab(text: 'طلبات الإجازة'),
          ],
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLeaveTypesTab(provider),
                _buildLeaveRequestsTab(provider),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddLeaveTypeDialog(context, provider);
          } else {
            _showAddLeaveRequestDialog(context, provider);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLeaveTypesTab(LeaveProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: provider.leaveTypes.length,
      itemBuilder: (context, index) {
        final leaveType = provider.leaveTypes[index];
        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.event,
                  color: colorScheme.onPrimaryContainer),
            ),
            title: Text(leaveType.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الكود: ${leaveType.code}'),
                Text('أيام الافتراضي: ${leaveType.defaultDays}'),
                Text(leaveType.isPaid ? 'مدفوعة الأجر' : 'بدون أجر'),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'delete') {
                  _confirmDeleteLeaveType(context, provider, leaveType);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'delete', child: Text('حذف')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeaveRequestsTab(LeaveProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final db = context.read<AppDatabase>();

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: provider.leaveRequests.length,
      itemBuilder: (context, index) {
        final request = provider.leaveRequests[index];
        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: _statusColor(request.status, colorScheme),
              child: Icon(_statusIcon(request.status),
                  color: Colors.white, size: 20),
            ),
            title: FutureBuilder<HREmployee?>(
              future: (db.select(db.hREmployees)
                    ..where((t) => t.id.equals(request.employeeId)))
                  .getSingleOrNull(),
              builder: (context, snapshot) => Text(
                snapshot.data?.name ?? 'موظف غير معروف',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<LeaveType?>(
                  future: (db.select(db.leaveTypes)
                        ..where((t) => t.id.equals(request.leaveTypeId)))
                      .getSingleOrNull(),
                  builder: (context, snapshot) =>
                      Text('النوع: ${snapshot.data?.name ?? 'غير معروف'}'),
                ),
                Text(
                  'من: ${intl.DateFormat('yyyy-MM-dd').format(request.startDate)}  إلى: ${intl.DateFormat('yyyy-MM-dd').format(request.endDate)}',
                ),
                Text('الأيام: ${request.totalDays}'),
                if (request.reason != null && request.reason!.isNotEmpty)
                  Text('السبب: ${request.reason}'),
                Text('الحالة: ${_statusText(request.status)}'),
              ],
            ),
            trailing: request.status == 'PENDING'
                ? PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'approve') {
                        _approveRequest(context, provider, request);
                      } else if (val == 'reject') {
                        _rejectRequest(context, provider, request);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'approve', child: Text('موافقة')),
                      const PopupMenuItem(
                          value: 'reject', child: Text('رفض')),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  Color _statusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'APPROVED':
        return Colors.green.shade700;
      case 'REJECTED':
        return Colors.red.shade700;
      default:
        return colorScheme.primary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'APPROVED':
        return Icons.check;
      case 'REJECTED':
        return Icons.close;
      default:
        return Icons.hourglass_top;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'PENDING':
        return 'قيد الانتظار';
      case 'APPROVED':
        return 'موافق عليها';
      case 'REJECTED':
        return 'مرفوضة';
      case 'CANCELLED':
        return 'ملغاة';
      default:
        return status;
    }
  }

  void _showAddLeaveTypeDialog(BuildContext context, LeaveProvider provider) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final daysController = TextEditingController(text: '30');
    final isPaid = ValueNotifier<bool>(true);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة نوع إجازة'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الإجازة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'الكود',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'أيام الافتراضي',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<bool>(
                valueListenable: isPaid,
                builder: (context, value, _) => SwitchListTile(
                  title: const Text('مدفوعة الأجر'),
                  value: value,
                  onChanged: (v) => isPaid.value = v,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                AppSnackBar.warning(context, 'يرجى إدخال اسم الإجازة');
                return;
              }
              if (codeController.text.isEmpty) {
                AppSnackBar.warning(context, 'يرجى إدخال الكود');
                return;
              }
              final days = int.tryParse(daysController.text) ?? 0;
              if (days <= 0) {
                AppSnackBar.warning(context, 'يرجى إدخال عدد أيام صحيح');
                return;
              }
              provider.createLeaveType(
                name: nameController.text,
                code: codeController.text,
                defaultDays: days,
                isPaid: isPaid.value,
              );
              Navigator.pop(context);
              AppSnackBar.success(context, 'تم إضافة نوع الإجازة');
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showAddLeaveRequestDialog(
      BuildContext context, LeaveProvider provider) {
    final db = context.read<AppDatabase>();
    final employeeIdController = TextEditingController();
    final reasonController = TextEditingController();
    final startDateController = TextEditingController();
    final endDateController = TextEditingController();
    final totalDaysController = TextEditingController();
    String? selectedLeaveTypeId;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('طلب إجازة جديد'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<List<HREmployee>>(
                    future: db.select(db.hREmployees).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'الموظف',
                          border: OutlineInputBorder(),
                        ),
                        items: snapshot.data!
                            .map((e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text(e.name),
                                ))
                            .toList(),
                        onChanged: (v) {
                          employeeIdController.text = v ?? '';
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'نوع الإجازة',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedLeaveTypeId,
                    items: provider.leaveTypes
                        .map((e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(e.name),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() => selectedLeaveTypeId = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: startDateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'تاريخ البداية',
                      hintText: 'YYYY-MM-DD',
                      border: OutlineInputBorder(),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        startDateController.text =
                            date.toIso8601String().substring(0, 10);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: endDateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'تاريخ النهاية',
                      hintText: 'YYYY-MM-DD',
                      border: OutlineInputBorder(),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        endDateController.text =
                            date.toIso8601String().substring(0, 10);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: totalDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'عدد الأيام',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'سبب الإجازة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (employeeIdController.text.isEmpty) {
                  AppSnackBar.warning(context, 'يرجى اختيار الموظف');
                  return;
                }
                if (selectedLeaveTypeId == null) {
                  AppSnackBar.warning(context, 'يرجى اختيار نوع الإجازة');
                  return;
                }
                final startDate =
                    DateTime.tryParse(startDateController.text);
                final endDate =
                    DateTime.tryParse(endDateController.text);
                if (startDate == null || endDate == null) {
                  AppSnackBar.warning(
                      context, 'يرجى إدخال تواريخ صحيحة');
                  return;
                }
                final totalDays =
                    int.tryParse(totalDaysController.text) ?? 0;
                if (totalDays <= 0) {
                  AppSnackBar.warning(
                      context, 'يرجى إدخال عدد أيام صحيح');
                  return;
                }
                provider.createLeaveRequest(
                  employeeId: employeeIdController.text,
                  leaveTypeId: selectedLeaveTypeId!,
                  startDate: startDate,
                  endDate: endDate,
                  totalDays: totalDays,
                  reason: reasonController.text.isEmpty
                      ? null
                      : reasonController.text,
                );
                Navigator.pop(context);
                AppSnackBar.success(context, 'تم إرسال طلب الإجازة');
              },
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }

  void _approveRequest(
    BuildContext context,
    LeaveProvider provider,
    LeaveRequest request,
  ) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('موافقة على الإجازة'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: 'ملاحظات (اختياري)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.approveLeaveRequest(
                requestId: request.id,
                approvedBy: 'current_user',
                note: noteController.text.isEmpty
                    ? null
                    : noteController.text,
              );
              Navigator.pop(context);
              AppSnackBar.success(context, 'تمت الموافقة على الإجازة');
            },
            child: const Text('موافقة'),
          ),
        ],
      ),
    );
  }

  void _rejectRequest(
    BuildContext context,
    LeaveProvider provider,
    LeaveRequest request,
  ) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض الإجازة'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'سبب الرفض',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonController.text.isEmpty) {
                AppSnackBar.warning(context, 'يرجى إدخال سبب الرفض');
                return;
              }
              provider.rejectLeaveRequest(
                requestId: request.id,
                rejectedBy: 'current_user',
                reason: reasonController.text,
              );
              Navigator.pop(context);
              AppSnackBar.success(context, 'تم رفض الإجازة');
            },
            child: const Text('رفض', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteLeaveType(
    BuildContext context,
    LeaveProvider provider,
    LeaveType leaveType,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف نوع الإجازة "${leaveType.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              AppSnackBar.success(context, 'تم حذف نوع الإجازة');
            },
            child:
                const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
