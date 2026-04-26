import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

/// A reusable widget for selecting an existing customer/supplier or adding a new one.
///
/// Features:
/// - Searchable dropdown for existing entities
/// - Option to add a new entity directly
/// - Clear visual distinction between selection modes
class EntityPickerDropdown extends StatefulWidget {
  final AppDatabase db;
  final String labelText;
  final String hintText;
  final String addNewLabel;
  final String selectLabel;
  final dynamic value;
  final void Function(dynamic value)? onChanged;
  final String Function(dynamic) itemText;
  final Future<dynamic>? Function(String)? onAddNew;
  final String entityTypeLabel;
  final Stream<List<dynamic>> Function(AppDatabase) streamBuilder;

  const EntityPickerDropdown({
    super.key,
    required this.db,
    required this.labelText,
    required this.hintText,
    required this.addNewLabel,
    required this.selectLabel,
    required this.itemText,
    required this.streamBuilder,
    this.value,
    this.onChanged,
    this.onAddNew,
    this.entityTypeLabel = '',
  });

  @override
  State<EntityPickerDropdown> createState() => _EntityPickerDropdownState();
}

class _EntityPickerDropdownState extends State<EntityPickerDropdown> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isAddingNew = false;
  final TextEditingController _newEntityController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _newEntityController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isAddingNew = !_isAddingNew;
      if (!_isAddingNew) _newEntityController.clear();
    });
  }

  Future<void> _saveNew() async {
    if (_newEntityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الرجاء إدخال اسم ${widget.entityTypeLabel}')),
      );
      return;
    }

    if (widget.onAddNew != null) {
      var addNewFn = widget.onAddNew;
      if (addNewFn != null) {
        final newEntity = await addNewFn(_newEntityController.text.trim());
        if (newEntity != null) {
          widget.onChanged?.call(newEntity);
          setState(() {
            _isAddingNew = false;
            _newEntityController.clear();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isAddingNew ? _toggleMode : null,
                icon: const Icon(Icons.search, size: 18),
                label: Text(widget.selectLabel),
                style: OutlinedButton.styleFrom(
                  backgroundColor: !_isAddingNew
                      ? theme.colorScheme.primaryContainer
                      : null,
                  foregroundColor: !_isAddingNew
                      ? theme.colorScheme.onPrimaryContainer
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: !_isAddingNew ? _toggleMode : null,
                icon: const Icon(Icons.add, size: 18),
                label: Text(widget.addNewLabel),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _isAddingNew
                      ? theme.colorScheme.primaryContainer
                      : null,
                  foregroundColor: _isAddingNew
                      ? theme.colorScheme.onPrimaryContainer
                      : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (!_isAddingNew) ...[
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: widget.hintText,
              hintText: 'بحث...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 8),

          StreamBuilder<List<dynamic>>(
            stream: widget.streamBuilder(widget.db),
            builder: (context, snapshot) {
              final allItems = snapshot.data ?? [];
              final filtered = _searchQuery.isEmpty
                  ? allItems
                  : allItems
                        .where(
                          (item) => widget
                              .itemText(item)
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()),
                        )
                        .toList();

              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<dynamic>(
                  initialValue: widget.value,
                  decoration: InputDecoration(
                    labelText: widget.labelText,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  isExpanded: true,
                  items: filtered
                      .map(
                        (item) => DropdownMenuItem<dynamic>(
                          value: item,
                          child: Text(
                            widget.itemText(item),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: widget.onChanged,
                ),
              );
            },
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_add, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'إضافة ${widget.entityTypeLabel} جديد',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newEntityController,
                  decoration: InputDecoration(
                    labelText: 'اسم ${widget.entityTypeLabel}',
                    hintText: 'أدخل اسم ${widget.entityTypeLabel}',
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                  ),
                  autofocus: true,
                  onSubmitted: (_) => _saveNew(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isAddingNew = false;
                          _newEntityController.clear();
                        });
                      },
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _saveNew,
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Customer picker for sales screens
class CustomerPicker extends StatelessWidget {
  final AppDatabase db;
  final Customer? value;
  final void Function(Customer?)? onChanged;

  const CustomerPicker({
    super.key,
    required this.db,
    this.value,
    this.onChanged,
  });

  Future<Customer?> _addNewCustomer(String name) async {
    final id = drift.Value(const Uuid().v4());
    await db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(
            id: id,
            name: name,
            createdAt: drift.Value(DateTime.now()),
          ),
        );
    final result = await (db.select(
      db.customers,
    )..where((c) => c.name.equals(name))).get();
    return result.isNotEmpty ? result.first : null;
  }

  @override
  Widget build(BuildContext context) {
    return EntityPickerDropdown(
      db: db,
      streamBuilder: (database) => database.select(database.customers).watch(),
      labelText: 'اختيار العميل',
      hintText: 'بحث عن عميل...',
      selectLabel: 'اختيار عميل',
      addNewLabel: 'عميل جديد',
      itemText: (c) => (c as Customer).name,
      value: value,
      onChanged: onChanged != null ? (v) => onChanged!(v as Customer?) : null,
      onAddNew: _addNewCustomer,
      entityTypeLabel: 'عميل',
    );
  }
}

/// Supplier picker for purchase screens
class SupplierPicker extends StatelessWidget {
  final AppDatabase db;
  final Supplier? value;
  final void Function(Supplier?)? onChanged;

  const SupplierPicker({
    super.key,
    required this.db,
    this.value,
    this.onChanged,
  });

  Future<Supplier?> _addNewSupplier(String name) async {
    final id = drift.Value(const Uuid().v4());
    await db
        .into(db.suppliers)
        .insert(
          SuppliersCompanion.insert(
            id: id,
            name: name,
            createdAt: drift.Value(DateTime.now()),
          ),
        );
    final result = await (db.select(
      db.suppliers,
    )..where((s) => s.name.equals(name))).get();
    return result.isNotEmpty ? result.first : null;
  }

  @override
  Widget build(BuildContext context) {
    return EntityPickerDropdown(
      db: db,
      streamBuilder: (database) => database.select(database.suppliers).watch(),
      labelText: 'اختيار المورد',
      hintText: 'بحث عن مورد...',
      selectLabel: 'اختيار مورد',
      addNewLabel: 'مورد جديد',
      itemText: (s) => (s as Supplier).name,
      value: value,
      onChanged: onChanged != null ? (v) => onChanged!(v as Supplier?) : null,
      onAddNew: _addNewSupplier,
      entityTypeLabel: 'مورد',
    );
  }
}
