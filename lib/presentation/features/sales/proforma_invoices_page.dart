import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:supermarket/presentation/features/sales/proforma_provider.dart';
import 'package:supermarket/presentation/widgets/app_snack_bar.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class ProformaInvoicesPage extends StatefulWidget {
  const ProformaInvoicesPage({super.key});

  @override
  State<ProformaInvoicesPage> createState() => _ProformaInvoicesPageState();
}

class _ProformaInvoicesPageState extends State<ProformaInvoicesPage> {
  DocumentStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProformaProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProformaProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('عروض الأسعار (برو فورما)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'إنشاء عرض سعر جديد',
            onPressed: () => _showCreateDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusFilter(),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.proformas.isEmpty
                    ? const Center(child: Text('لا توجد عروض أسعار'))
                    : _buildProformasList(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SegmentedButton<DocumentStatus?>(
        segments: const [
          ButtonSegment(value: null, label: Text('الكل')),
          ButtonSegment(value: DocumentStatus.draft, label: Text('مسودة')),
          ButtonSegment(value: DocumentStatus.posted, label: Text('معتمد')),
          ButtonSegment(value: DocumentStatus.received, label: Text('محوّل')),
          ButtonSegment(value: DocumentStatus.cancelled, label: Text('ملغي')),
        ],
        selected: {_selectedStatus},
        onSelectionChanged: (Set<DocumentStatus?> selected) {
          setState(() => _selectedStatus = selected.first);
          context.read<ProformaProvider>().loadData(status: _selectedStatus);
        },
      ),
    );
  }

  Widget _buildProformasList(ProformaProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: provider.proformas.length,
      itemBuilder: (context, index) {
        final proforma = provider.proformas[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(proforma.status).withOpacity(0.1),
              child: Icon(
                _statusIcon(proforma.status),
                color: _statusColor(proforma.status),
                size: 20,
              ),
            ),
            title: Text('عرض سعر #${proforma.id.substring(0, 8)}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المبلغ: ${proforma.total} ر.س'),
                Text('الحالة: ${_statusText(proforma.status)}'),
                if (proforma.validUntil != null)
                  Text('صالح حتى: ${proforma.validUntil}'),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (action) => _handleAction(context, action, proforma),
              itemBuilder: (context) => [
                if (proforma.status == DocumentStatus.draft) ...[
                  const PopupMenuItem(value: 'view', child: Text('عرض')),
                  const PopupMenuItem(value: 'cancel', child: Text('إلغاء')),
                ],
                if (proforma.status == DocumentStatus.posted)
                  const PopupMenuItem(value: 'convert', child: Text('تحويل لفاتورة')),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateDialog(BuildContext context) {
    // Simplified creation dialog - in production would have full item entry
    final customerController = TextEditingController();
    final notesController = TextEditingController();
    final validUntilController = TextEditingController(
      text: DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 30))),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء عرض سعر جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: customerController,
                decoration: const InputDecoration(
                  labelText: 'اسم العميل',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: validUntilController,
                decoration: const InputDecoration(
                  labelText: 'صالح حتى',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
            onPressed: () async {
              Navigator.pop(context);
              // Note: Full implementation would need item selection
              AppSnackBar.info(context, 'تم إنشاء العرض - يحتاج إلى إضافة الأصناف');
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action, ProformaInvoice proforma) {
    final provider = context.read<ProformaProvider>();
    switch (action) {
      case 'cancel':
        provider.cancelProforma(proforma.id);
        AppSnackBar.success(context, 'تم إلغاء العرض');
        break;
      case 'convert':
        AppSnackBar.info(context, 'تحويل لفاتورة - قيد التطوير');
        break;
    }
  }

  Color _statusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.posted: return Colors.green;
      case DocumentStatus.received: return Colors.blue;
      case DocumentStatus.cancelled: return Colors.red;
      default: return Colors.orange;
    }
  }

  IconData _statusIcon(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.posted: return Icons.check_circle;
      case DocumentStatus.received: return Icons.swap_horiz;
      case DocumentStatus.cancelled: return Icons.cancel;
      default: return Icons.edit_note;
    }
  }

  String _statusText(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.posted: return 'معتمد';
      case DocumentStatus.received: return 'محوّل لفاتورة';
      case DocumentStatus.cancelled: return 'ملغي';
      default: return 'مسودة';
    }
  }
}
