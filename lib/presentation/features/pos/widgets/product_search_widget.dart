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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.searchProducts,
              suffixIcon: const Icon(Icons.search),
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                context.read<PosBloc>().add(AddProductBySku(value));
              }
            },
          ),
          const Expanded(
            child: SizedBox(), // Placeholder for search results
          ),
        ],
      ),
    );
  }
}
