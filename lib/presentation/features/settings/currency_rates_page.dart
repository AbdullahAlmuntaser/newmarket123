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

          if (currencies.isEmpty) {
            return const Center(child: Text('لا توجد عملات مضافة حالياً. اضغط على + لإضافة عملة.'));
          }

          return ListView.builder(
            itemCount: currencies.length,
            itemBuilder: (context, index) {
              final currency = currencies[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(currency.code.substring(0, 1)),
                  ),
                  title: Text('${currency.name} (${currency.code})'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('السعر مقابل الأساسي: ${currency.exchangeRate.toStringAsFixed(4)}'),
                      if (currency.isBase)
                        const Text('هذه هي العملة الأساسية', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
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
    final fractionalUnitController = TextEditingController();
    final decimalPlacesController = TextEditingController(text: '2');
    bool isBase = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة عملة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'رمز العملة (USD)',
                    hintText: 'مثلاً: USD, YER, SAR',
                  ),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم العملة (دولار أمريكي)',
                    hintText: 'اسم العملة الكامل',
                  ),
                ),
                TextField(
                  controller: fractionalUnitController,
                  decoration: const InputDecoration(labelText: 'فكة العملة (سنت)'),
                ),
                TextField(
                  controller: decimalPlacesController,
                  decoration: const InputDecoration(labelText: 'عدد الكسور العشرية'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: rateController,
                  decoration: const InputDecoration(
                    labelText: 'سعر الصرف مقابل الأساسي',
                    helperText: 'إذا كانت هذه العملة الأساسية، أدخل 1',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  title: const Text('عملة أساسية'),
                  value: isBase,
                  onChanged: (value) {
                    setDialogState(() {
                      isBase = value ?? false;
                      if (isBase) {
                        rateController.text = '1.0';
                      }
                    });
                  },
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
                final rateText = rateController.text.trim();
                final rate = double.tryParse(rateText);
                final decimals = int.tryParse(decimalPlacesController.text) ?? 2;
                
                if (codeController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال رمز العملة')),
                  );
                  return;
                }
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم العملة')),
                  );
                  return;
                }
                if (rate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال سعر صرف صحيح')),
                  );
                  return;
                }

                try {
                  // If setting as base, we should unset others
                  if (isBase) {
                    await (db.update(db.currencies)..where((t) => t.isBase.equals(true)))
                        .write(const CurrenciesCompanion(isBase: drift.Value(false)));
                  }

                  await db.into(db.currencies).insert(
                    CurrenciesCompanion.insert(
                      code: codeController.text.trim().toUpperCase(),
                      name: nameController.text.trim(),
                      fractionalUnit: drift.Value(fractionalUnitController.text.trim()),
                      decimalPlaces: drift.Value(decimals),
                      exchangeRate: drift.Value(rate),
                      isBase: drift.Value(isBase),
                    ),
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ أثناء الحفظ: $e')),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل العملة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(text: currency.code),
                  decoration: const InputDecoration(labelText: 'رمز العملة'),
                  readOnly: true,
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم العملة'),
                ),
                TextField(
                  controller: fractionalUnitController,
                  decoration: const InputDecoration(labelText: 'فكة العملة'),
                ),
                TextField(
                  controller: decimalPlacesController,
                  decoration: const InputDecoration(labelText: 'عدد الكسور'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: rateController,
                  decoration: const InputDecoration(labelText: 'سعر الصرف'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  title: const Text('عملة أساسية'),
                  value: isBase,
                  onChanged: (value) {
                    setDialogState(() {
                      isBase = value ?? false;
                      if (isBase) {
                        rateController.text = '1.0';
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final rate = double.tryParse(rateController.text);
                final decimals = int.tryParse(decimalPlacesController.text) ?? 2;
                
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم العملة')),
                  );
                  return;
                }
                if (rate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال سعر صرف صحيح')),
                  );
                  return;
                }

                try {
                  // If setting as base, we should unset others
                  if (isBase && !currency.isBase) {
                    await (db.update(db.currencies)..where((t) => t.isBase.equals(true)))
                        .write(const CurrenciesCompanion(isBase: drift.Value(false)));
                  }

                  await db.update(db.currencies).replace(
                    currency.copyWith(
                      name: nameController.text.trim(),
                      fractionalUnit: drift.Value(fractionalUnitController.text.trim()),
                      decimalPlaces: decimals,
                      exchangeRate: rate,
                      isBase: isBase,
                    ),
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ أثناء التعديل: $e')),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
