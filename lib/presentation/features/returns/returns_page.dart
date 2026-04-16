import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supermarket/presentation/features/returns/create_return_page.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class ReturnsPage extends StatefulWidget {
  const ReturnsPage({super.key});

  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.returnsManagement),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: l10n.salesReturns,
              icon: const Icon(Icons.keyboard_return),
            ),
            Tab(
              text: l10n.purchaseReturns,
              icon: const Icon(Icons.assignment_return),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReturnsList<SalesReturn>(db, db.salesReturns, l10n),
          _buildReturnsList<PurchaseReturn>(db, db.purchaseReturns, l10n),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReturnDialog(context, l10n),
        label: Text(l10n.newReturn),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildReturnsList<T>(
    AppDatabase db,
    dynamic table,
    AppLocalizations l10n,
  ) {
    return StreamBuilder<List<dynamic>>(
      stream: (db.select(table)).watch(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) return Center(child: Text(l10n.noReturnsFound));
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(l10n.returnIdLabel(item.id.substring(0, 8))),
              subtitle: Text(
                '${l10n.amountReturnedLabel(item.amountReturned.toString())}\n${l10n.dateLabel(DateFormat('yyyy-MM-dd').format(item.createdAt))}',
              ),
              trailing: const Icon(Icons.chevron_right),
            );
          },
        );
      },
    );
  }

  void _showAddReturnDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.createReturn),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.shopping_bag),
              title: Text(l10n.fromSale),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const CreateReturnPage(type: ReturnType.sale),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: Text(l10n.fromPurchase),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const CreateReturnPage(type: ReturnType.purchase),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
