import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  bool _isLoading = true;
  List<Promotion> _promotions = const [];

  AppDatabase get _db => context.read<AppDatabase>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPromotions());
  }

  Future<void> _loadPromotions() async {
    setState(() => _isLoading = true);
    try {
      final rows = await (_db.select(_db.promotions)
            ..orderBy([(p) => drift.OrderingTerm.desc(p.createdAt)]))
          .get();
      if (mounted) setState(() => _promotions = rows);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل العروض: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createDemoPromotion() async {
    final now = DateTime.now();
    await _db.into(_db.promotions).insert(
          PromotionsCompanion.insert(
            name: 'خصم تجريبي 10%',
            type: 'PERCENTAGE_DISCOUNT',
            value: 10,
            startDate: now,
            endDate: now.add(const Duration(days: 30)),
            minPurchaseAmount: const drift.Value(0),
          ),
        );
    await _loadPromotions();
  }

  Future<void> _togglePromotion(Promotion promotion) async {
    await (_db.update(_db.promotions)..where((p) => p.id.equals(promotion.id)))
        .write(PromotionsCompanion(isActive: drift.Value(!promotion.isActive)));
    await _loadPromotions();
  }

  Future<void> _deletePromotion(Promotion promotion) async {
    await (_db.delete(_db.promotions)..where((p) => p.id.equals(promotion.id))).go();
    await _loadPromotions();
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'PERCENTAGE_DISCOUNT':
        return 'خصم نسبة';
      case 'FIXED_DISCOUNT':
        return 'خصم مبلغ';
      case 'BOGO':
        return 'اشتر واحصل';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العروض والبروموشنز'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _isLoading ? null : _loadPromotions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDemoPromotion,
        icon: const Icon(Icons.local_offer),
        label: const Text('عرض تجريبي'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPromotions,
              child: _promotions.isEmpty
                  ? const ListView(
                      children: [
                        SizedBox(height: 160),
                        Center(child: Text('لا توجد عروض حالياً')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _promotions.length,
                      itemBuilder: (context, index) {
                        final promotion = _promotions[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.local_offer,
                              color: promotion.isActive ? Colors.green : Colors.grey,
                            ),
                            title: Text(promotion.name),
                            subtitle: Text(
                              '${_typeLabel(promotion.type)} • القيمة ${promotion.value}\n'
                              '${DateFormat('yyyy-MM-dd').format(promotion.startDate)} - ${DateFormat('yyyy-MM-dd').format(promotion.endDate)}',
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'toggle') _togglePromotion(promotion);
                                if (value == 'delete') _deletePromotion(promotion);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(promotion.isActive ? 'تعطيل' : 'تفعيل'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('حذف'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
