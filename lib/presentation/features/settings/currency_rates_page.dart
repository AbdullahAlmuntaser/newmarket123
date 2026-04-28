import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' as drift;

class CurrencyRatesPage extends StatefulWidget {
  const CurrencyRatesPage({super.key});

  @override
  State<CurrencyRatesPage> createState() => _CurrencyRatesPageState();
}

class _CurrencyRatesPageState extends State<CurrencyRatesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use context inside postFrameCallback to avoid async gap issues
      context
          .read<AppDatabase>()
          .select(context.read<AppDatabase>().currencies)
          .get();
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة أسعار صرف العملات')),
      body: StreamBuilder<List<Currency>>(
        stream: db.select(db.currencies).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final currencies = snapshot.data!;

          return ListView.builder(
            itemCount: currencies.length,
            itemBuilder: (context, index) {
              final currency = currencies[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('${currency.name} (${currency.code})'),
                  subtitle: Text(
                    'السعر مقابل الأساسي: ${currency.exchangeRate.toStringAsFixed(4)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () =>
                        _showEditCurrencyDialog(context, db, currency),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCurrencyDialog(context, db),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCurrencyDialog(BuildContext context, AppDatabase db) {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final rateController = TextEditingController();
    final fractionalUnitController = TextEditingController(); // جديد
    final decimalPlacesController = TextEditingController(text: '2'); // جديد
    bool isBase = false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة عملة جديدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'رمز العملة (USD)'),
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم العملة (دولار أمريكي)'),
              ),
              TextField(
                controller: fractionalUnitController,
                decoration: const InputDecoration(labelText: 'فكة العملة (سنت)'),
              ),
              TextField(
                controller: decimalPlacesController,
                decoration: const InputDecoration(labelText: 'عدد الكسور'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(labelText: 'سعر الصرف مقابل الأساسي'),
                keyboardType: TextInputType.number,
              ),
              Row(
                children: [
                  Checkbox(
                    value: isBase,
                    onChanged: (value) => setState(() => isBase = value ?? false),
                  ),
                  const Text('عملة أساسية'),
                ],
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
              final rate = double.tryParse(rateController.text);
              final decimals = int.tryParse(decimalPlacesController.text);
              if (codeController.text.isNotEmpty && nameController.text.isNotEmpty && rate != null) {
                await db.into(db.currencies).insert(
                  CurrenciesCompanion.insert(
                    code: codeController.text,
                    name: nameController.text,
                    fractionalUnit: drift.Value(fractionalUnitController.text),
                    decimalPlaces: drift.Value(decimals ?? 2),
                    exchangeRate: drift.Value(rate),
                    isBase: drift.Value(isBase),
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showEditCurrencyDialog(BuildContext context, AppDatabase db, Currency currency) {
    final nameController = TextEditingController(text: currency.name);
    final rateController = TextEditingController(text: currency.exchangeRate.toString());
    final fractionalUnitController = TextEditingController(text: currency.fractionalUnit ?? '');
    final decimalPlacesController = TextEditingController(text: currency.decimalPlaces.toString());
    bool isBase = currency.isBase;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل العملة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: TextEditingController(text: currency.code), decoration: const InputDecoration(labelText: 'رمز العملة'), readOnly: true),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم العملة')),
              TextField(controller: fractionalUnitController, decoration: const InputDecoration(labelText: 'فكة العملة')),
              TextField(controller: decimalPlacesController, decoration: const InputDecoration(labelText: 'عدد الكسور'), keyboardType: TextInputType.number),
              TextField(controller: rateController, decoration: const InputDecoration(labelText: 'سعر الصرف'), keyboardType: TextInputType.number),
              Row(
                children: [
                  Checkbox(value: isBase, onChanged: (value) => setState(() => isBase = value ?? false)),
                  const Text('عملة أساسية'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final rate = double.tryParse(rateController.text);
              final decimals = int.tryParse(decimalPlacesController.text);
              if (rate != null) {
                await db.update(db.currencies).replace(
                  currency.copyWith(
                    name: nameController.text,
                    fractionalUnit: drift.Value(fractionalUnitController.text),
                    decimalPlaces: decimals ?? 2,
                    exchangeRate: rate,
                    isBase: isBase,
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
