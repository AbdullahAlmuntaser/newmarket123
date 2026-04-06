import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/presentation/features/accounting/asset_provider.dart';
import 'package:supermarket/presentation/features/accounting/widgets/add_edit_asset_dialog.dart';

class FixedAssetsPage extends StatefulWidget {
  const FixedAssetsPage({super.key});

  @override
  State<FixedAssetsPage> createState() => _FixedAssetsPageState();
}

class _FixedAssetsPageState extends State<FixedAssetsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AssetProvider>().loadAssets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssetProvider>();
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(locale: 'ar_SA', symbol: 'ر.س');

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأصول الثابتة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تأكيد'),
                  content: const Text('هل تريد بالتأكيد تشغيل الإهلاك الشهري لجميع الأصول؟ ستتم العملية في الخلفية.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
                    ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('تشغيل')),
                  ],
                ),
              );
              if (confirmed ?? false) {
                await provider.runDepreciation();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت عملية حساب الإهلاك بنجاح.'), backgroundColor: Colors.green),
                  );
                }
              }
            },
            tooltip: 'حساب الإهلاك الشهري',
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.assets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business_center_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('لا توجد أصول ثابتة مسجلة حالياً.', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('ابدأ بإضافة أصل جديد من الزر أدناه.', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: provider.assets.length,
                  itemBuilder: (context, index) {
                    final asset = provider.assets[index];
                    final bookValue = asset.cost - asset.accumulatedDepreciation;

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(asset.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const Divider(height: 20),
                            _buildInfoRow(
                              icon: Icons.calendar_today,
                              label: 'تاريخ الشراء',
                              value: DateFormat('yyyy-MM-dd').format(asset.purchaseDate),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              icon: Icons.monetization_on,
                              label: 'التكلفة الأصلية',
                              value: currencyFormat.format(asset.cost),
                            ),
                            const SizedBox(height: 8),
                             _buildInfoRow(
                              icon: Icons.hourglass_bottom,
                              label: 'العمر الافتراضي',
                              value: '${asset.usefulLifeYears} سنوات',
                            ),
                             const SizedBox(height: 8),
                            _buildInfoRow(
                              icon: Icons.recycling,
                              label: 'قيمة الخردة',
                              value: currencyFormat.format(asset.salvageValue),
                            ),
                             const SizedBox(height: 8),
                            _buildInfoRow(
                              icon: Icons.trending_down,
                              label: 'الإهلاك المتراكم',
                              value: currencyFormat.format(asset.accumulatedDepreciation),
                              color: Colors.orange.shade700,
                            ),
                            const Divider(height: 20),
                             _buildInfoRow(
                              icon: Icons.book,
                              label: 'صافي القيمة الدفترية',
                              value: currencyFormat.format(bookValue),
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (ctx) => AddEditAssetDialog(
            assetProvider: provider,
          ),
        ),
        label: const Text('إضافة أصل'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value, Color? color, bool isTotal = false}) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: color,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      fontSize: isTotal ? 18 : 16,
    );
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label:', style: style?.copyWith(color: Colors.grey.shade700)),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}
