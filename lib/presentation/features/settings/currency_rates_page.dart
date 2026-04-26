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
    bool isBase = false; // Local state for checkbox

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
                decoration: const InputDecoration(
                  labelText: 'رمز العملة (USD)',
                ),
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم العملة (دولار أمريكي)',
                ),
              ),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(
                  labelText: 'سعر الصرف مقابل الأساسي',
                ),
                keyboardType: TextInputType.number,
              ),
              Row(
                children: [
                  Checkbox(
                    value: isBase,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          isBase = value;
                        }); // Update local state
                      }
                    },
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
              if (codeController.text.isNotEmpty &&
                  nameController.text.isNotEmpty &&
                  rateController.text.isNotEmpty) {
                final rate = double.tryParse(rateController.text);
                if (rate != null) {
                  await db
                      .into(db.currencies)
                      .insert(
                        CurrenciesCompanion.insert(
                          code: codeController.text,
                          name: nameController.text,
                          exchangeRate: drift.Value(rate),
                          isBase: drift.Value(isBase),
                        ),
                      );
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showEditCurrencyDialog(
    BuildContext context,
    AppDatabase db,
    Currency currency,
  ) {
    final codeController = TextEditingController(text: currency.code);
    final nameController = TextEditingController(text: currency.name);
    final rateController = TextEditingController(
      text: currency.exchangeRate.toString(),
    );
    bool isBase = currency.isBase; // Initialize local state from currency

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل سعر الصرف'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'رمز العملة'),
                readOnly: true,
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم العملة'),
                readOnly: true,
              ),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(
                  labelText: 'سعر الصرف مقابل الأساسي',
                ),
                keyboardType: TextInputType.number,
              ),
              Row(
                children: [
                  Checkbox(
                    value: isBase,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          isBase = value;
                        }); // Update local state
                      }
                    },
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
              if (rateController.text.isNotEmpty) {
                final rate = double.tryParse(rateController.text);
                if (rate != null) {
                  await db
                      .update(db.currencies)
                      .replace(
                        currency.copyWith(exchangeRate: rate, isBase: isBase),
                      );
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
