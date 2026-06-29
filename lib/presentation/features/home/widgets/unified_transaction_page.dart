import 'package:flutter/material.dart';
import 'package:supermarket/core/constants/app_colors.dart';
import 'package:supermarket/core/constants/app_dimensions.dart';

enum TransactionType {
  sale,
  purchase,
  saleReturn,
  purchaseReturn,
  quote,
  purchaseOrder,
  salesOrder,
}

class TransactionField {
  final String label;
  final String? hint;
  final bool required;
  final TransactionFieldType type;
  final List<String>? options;

  const TransactionField({
    required this.label,
    this.hint,
    this.required = false,
    this.type = TransactionFieldType.text,
    this.options,
  });
}

enum TransactionFieldType { text, number, dropdown, date, search, amount }

class UnifiedTransactionPage extends StatefulWidget {
  const UnifiedTransactionPage({super.key});

  @override
  State<UnifiedTransactionPage> createState() => _UnifiedTransactionPageState();
}

class _UnifiedTransactionPageState extends State<UnifiedTransactionPage> {
  TransactionType _selectedType = TransactionType.sale;
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final fields = _getFieldsForType(_selectedType);
    final title = _getTitleForType(_selectedType);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
            tooltip: 'إعدادات المعاملة',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: AppDimensions.sm),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                const Icon(Icons.swap_horiz, size: 20),
                const SizedBox(width: AppDimensions.sm),
                const Text('نوع العملية:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<TransactionType>(
                        value: _selectedType,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                              value: TransactionType.sale, child: Text('بيع')),
                          DropdownMenuItem(
                              value: TransactionType.purchase,
                              child: Text('شراء')),
                          DropdownMenuItem(
                              value: TransactionType.saleReturn,
                              child: Text('مرتجع بيع')),
                          DropdownMenuItem(
                              value: TransactionType.purchaseReturn,
                              child: Text('مرتجع شراء')),
                          DropdownMenuItem(
                              value: TransactionType.quote,
                              child: Text('عرض سعر')),
                          DropdownMenuItem(
                              value: TransactionType.purchaseOrder,
                              child: Text('طلب شراء')),
                          DropdownMenuItem(
                              value: TransactionType.salesOrder,
                              child: Text('طلبية عميل')),
                        ],
                        onChanged: (v) => setState(
                            () => _selectedType = v ?? TransactionType.sale),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormHeader(context),
                    const SizedBox(height: AppDimensions.lg),
                    ...fields.map((field) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppDimensions.md),
                          child: _buildField(context, field),
                        )),
                    const SizedBox(height: AppDimensions.lg),
                    _buildActionButtons(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormHeader(BuildContext context) {
    final config = _getConfigForType(_selectedType);
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: config.color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: config.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Icon(config.icon, color: config.color, size: 24),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(config.label,
                    style: TextStyle(
                        color: config.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text(config.description,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(BuildContext context, TransactionField field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(field.label,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (field.required)
              const Text(' *',
                  style: TextStyle(color: AppColors.error, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          decoration: InputDecoration(
            hintText: field.hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          keyboardType: field.type == TransactionFieldType.number ||
                  field.type == TransactionFieldType.amount
              ? TextInputType.number
              : TextInputType.text,
          validator: field.required
              ? (v) => (v == null || v.isEmpty) ? 'هذا الحقل مطلوب' : null
              : null,
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('إلغاء'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('تم حفظ المعاملة بنجاح'),
                      backgroundColor: AppColors.success),
                );
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('حفظ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
            ),
          ),
        ),
      ],
    );
  }

  _TypeConfig _getConfigForType(TransactionType type) {
    switch (type) {
      case TransactionType.sale:
        return const _TypeConfig('فاتورة بيع', 'إنشاء فاتورة بيع جديدة',
            Icons.point_of_sale, AppColors.opSales);
      case TransactionType.purchase:
        return const _TypeConfig('فاتورة شراء', 'إنشاء فاتورة شراء جديدة',
            Icons.shopping_bag, AppColors.opPurchases);
      case TransactionType.saleReturn:
        return const _TypeConfig('مرتجع بيع', 'إرجاع منتجات من فاتورة بيع',
            Icons.assignment_return, AppColors.warning);
      case TransactionType.purchaseReturn:
        return const _TypeConfig('مرتجع شراء', 'إرجاع منتجات لشركة شراء',
            Icons.assignment_return, AppColors.error);
      case TransactionType.quote:
        return const _TypeConfig('عرض سعر', 'إنشاء عرض سعر للعميل',
            Icons.request_quote, AppColors.info);
      case TransactionType.purchaseOrder:
        return const _TypeConfig('طلب شراء', 'إنشاء طلب شراء من مورد',
            Icons.receipt, AppColors.opPurchases);
      case TransactionType.salesOrder:
        return const _TypeConfig('طلبية عميل', 'استلام طلبية من عميل',
            Icons.shopping_cart_checkout, AppColors.opSales);
    }
  }

  String _getTitleForType(TransactionType type) {
    return _getConfigForType(type).label;
  }

  List<TransactionField> _getFieldsForType(TransactionType type) {
    const customerField = TransactionField(
        label: 'العميل',
        hint: 'اختر العميل',
        required: true,
        type: TransactionFieldType.search);
    const supplierField = TransactionField(
        label: 'المورد',
        hint: 'اختر المورد',
        required: true,
        type: TransactionFieldType.search);
    const dateField = TransactionField(
        label: 'التاريخ',
        hint: 'تاريخ المعاملة',
        required: true,
        type: TransactionFieldType.date);
    const notesField = TransactionField(
        label: 'ملاحظات',
        hint: 'ملاحظات إضافية',
        type: TransactionFieldType.text);
    const amountField = TransactionField(
        label: 'المبلغ',
        hint: '0.00',
        required: true,
        type: TransactionFieldType.amount);
    const paymentField = TransactionField(
        label: 'طريقة الدفع',
        hint: 'اختر طريقة الدفع',
        required: true,
        type: TransactionFieldType.dropdown,
        options: ['نقدي', 'بنكي', 'شيك']);

    switch (type) {
      case TransactionType.sale:
        return [
          customerField,
          dateField,
          amountField,
          paymentField,
          notesField
        ];
      case TransactionType.purchase:
        return [
          supplierField,
          dateField,
          amountField,
          paymentField,
          notesField
        ];
      case TransactionType.saleReturn:
        return [customerField, dateField, amountField, notesField];
      case TransactionType.purchaseReturn:
        return [supplierField, dateField, amountField, notesField];
      case TransactionType.quote:
        return [customerField, dateField, amountField, notesField];
      case TransactionType.purchaseOrder:
        return [supplierField, dateField, amountField, notesField];
      case TransactionType.salesOrder:
        return [customerField, dateField, amountField, notesField];
    }
  }
}

class _TypeConfig {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  const _TypeConfig(this.label, this.description, this.icon, this.color);
}
