import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/utils/erp_logic.dart' as erp;
import 'package:supermarket/core/utils/quantity.dart';

class SmartStockWidget extends StatelessWidget {
  final Product product;

  const SmartStockWidget({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();

    return StreamBuilder<List<UnitConversion>>(
      stream: (db.select(
        db.unitConversions,
      )..where((t) => t.productId.equals(product.id)))
          .watch(),
      builder: (context, snapshot) {
        final conversions = snapshot.data ?? [];
        final erpConversions = conversions
            .map((c) =>
                erp.UnitConversion(unitName: c.unitName, factor: c.factor))
            .toList();
        final formattedStock = erp.ErpLogic.formatInventory(
          totalBaseQty: Quantity(product.stock),
          baseUnitName: product.unit,
          conversions: erpConversions,
        );

        return Text(
          formattedStock,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        );
      },
    );
  }
}
