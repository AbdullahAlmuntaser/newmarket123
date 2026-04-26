import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';

class ProductSearchWidget extends StatelessWidget {
  final TextEditingController? controller;
  const ProductSearchWidget({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: l10n.searchProducts,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      onSubmitted: (value) {
        if (value.isNotEmpty) {
          context.read<PosBloc>().add(AddProductBySku(value));
          controller?.clear();
        }
      },
      onChanged: (value) {
        // Optional: Trigger real-time search
        // context.read<PosBloc>().add(SearchProducts(value));
      },
    );
  }
}
