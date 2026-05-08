import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/app_config_service.dart';
import '../../../data/datasources/local/app_database.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({super.key});

  @override
  AdvancedSettingsPageState createState() => AdvancedSettingsPageState();
}

class AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  late AppConfigService _configService;

  bool _allowNegativeStock = false;
  double _taxRate = 0.15;
  String _defaultWarehouse = '';
  String _defaultBranch = '';
  int _lowStockThreshold = 10;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _configService = AppConfigService(context.read<AppDatabase>());
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    _allowNegativeStock = await _configService.allowNegativeStock();
    _taxRate = await _configService.getTaxRate();
    _defaultWarehouse = await _configService.getDefaultWarehouseId();
    _defaultBranch = await _configService.getDefaultBranchId();
    _lowStockThreshold = await _configService.getLowStockThreshold();

    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    try {
      await _configService.setBool('allow_negative_stock', _allowNegativeStock);
      await _configService.setDouble('tax_rate', _taxRate);
      await _configService.setInt('low_stock_threshold', _lowStockThreshold);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الإعدادات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ الإعدادات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات المتقدمة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('السماح بالمخزون السلبي'),
              subtitle: const Text('السماح ببيع منتجات بدون رصيد كافٍ'),
              value: _allowNegativeStock,
              onChanged: (value) {
                setState(() => _allowNegativeStock = value);
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نسبة الضريبة (${(_taxRate * 100).toStringAsFixed(1)}%)',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Slider(
                    value: _taxRate,
                    min: 0,
                    max: 0.25,
                    divisions: 25,
                    label: '${(_taxRate * 100).toStringAsFixed(1)}%',
                    onChanged: (value) {
                      setState(() => _taxRate = value);
                    },
                  ),
                  const Text('تتراوح بين 0% و 25%',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('حد التنبيه للمخزون المنخفض',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Slider(
                    value: _lowStockThreshold.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: _lowStockThreshold.toString(),
                    onChanged: (value) {
                      setState(() => _lowStockThreshold = value.toInt());
                    },
                  ),
                  Text(
                      'سيتم التنبيه عندما يقل الرصيد عن $_lowStockThreshold وحدات',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المعرفات الافتراضية',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.warehouse),
                    title: const Text('المستودع الافتراضي'),
                    subtitle: Text(_defaultWarehouse),
                  ),
                  ListTile(
                    leading: const Icon(Icons.business),
                    title: const Text('الفرع الافتراضي'),
                    subtitle: Text(_defaultBranch),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('حفظ التغييرات'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
