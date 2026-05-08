import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/presentation/features/sales/widgets/sale_details_bottom_sheet.dart';
import 'package:supermarket/core/constants/app_enums.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final int _pageSize = 20;
  int _currentPage = 0;

  DateTime? _startDate;
  DateTime? _endDate;
  DocumentStatus? _statusFilter;
  String? _customerIdFilter;
  String? _warehouseIdFilter;
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sales),
        actions: [
          IconButton(
            icon:
                Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: 'فلترة',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _currentPage = 0;
              _startDate = null;
              _endDate = null;
              _statusFilter = null;
              _customerIdFilter = null;
              _warehouseIdFilter = null;
            }),
            tooltip: 'إعادة تعيين',
          ),
        ],
      ),
      drawer: const MainDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sales/invoice'),
        icon: const Icon(Icons.add),
        label: const Text('فاتورة مبيعات'),
      ),
      body: Column(
        children: [
          if (_showFilters) _buildFiltersPanel(context, db, l10n),
          Expanded(
            child: FutureBuilder<List<Sale>>(
              future: _fetchFilteredSales(db),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allSales = snapshot.data ?? [];
                if (allSales.isEmpty) {
                  return Center(child: Text(l10n.noSalesFound));
                }

                final start = _currentPage * _pageSize;
                final end = (start + _pageSize < allSales.length)
                    ? start + _pageSize
                    : allSales.length;
                final sales = allSales.sublist(start, end);

                return ListView.separated(
                  itemCount: sales.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(26),
                        child: Icon(
                          sale.paymentMethod == PaymentMethod.cash
                              ? Icons.money
                              : Icons.credit_card,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(l10n.saleIdLabel(sale.id.substring(0, 8))),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(sale.createdAt),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            sale.total.toStringAsFixed(2),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            sale.status == DocumentStatus.posted
                                ? l10n.synced
                                : 'غير مرحل',
                            style: TextStyle(
                              fontSize: 10,
                              color: sale.status == DocumentStatus.posted
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showSaleDetails(context, db, sale, l10n),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSaleDetails(
    BuildContext context,
    AppDatabase db,
    Sale sale,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          SaleDetailsBottomSheet(sale: sale, db: db, l10n: l10n),
    );
  }

  Widget _buildFiltersPanel(
      BuildContext context, AppDatabase db, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_startDate != null
                      ? DateFormat.yMMMd().format(_startDate!)
                      : 'من تاريخ'),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _startDate = date);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_endDate != null
                      ? DateFormat.yMMMd().format(_endDate!)
                      : 'إلى تاريخ'),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _endDate = date);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<DocumentStatus?>(
                  value: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'الحالة',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('كل الحالات')),
                    DropdownMenuItem(
                        value: DocumentStatus.draft, child: Text('مسودة')),
                    DropdownMenuItem(
                        value: DocumentStatus.posted, child: Text('مرحّل')),
                    DropdownMenuItem(
                        value: DocumentStatus.cancelled, child: Text('ملغي')),
                  ],
                  onChanged: (value) => setState(() => _statusFilter = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('بحث'),
                  onPressed: () => setState(() => _currentPage = 0),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _startDate = null;
                  _endDate = null;
                  _statusFilter = null;
                  _customerIdFilter = null;
                  _warehouseIdFilter = null;
                  _currentPage = 0;
                }),
                child: const Text('مسح'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<Sale>> _fetchFilteredSales(AppDatabase db) async {
    var query = db.select(db.sales);

    if (_startDate != null) {
      query = query
        ..where((s) => s.createdAt.isBiggerOrEqualValue(_startDate!));
    }
    if (_endDate != null) {
      query = query..where((s) => s.createdAt.isSmallerOrEqualValue(_endDate!));
    }
    if (_statusFilter != null) {
      query = query..where((s) => s.status.equals(_statusFilter!.index));
    }
    if (_customerIdFilter != null) {
      query = query..where((s) => s.customerId.equals(_customerIdFilter!));
    }
    if (_warehouseIdFilter != null) {
      query = query..where((s) => s.warehouseId.equals(_warehouseIdFilter!));
    }

    query = query..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }
}
