import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';

class ProductSearchWidget extends StatefulWidget {
  final TextEditingController? controller;
  const ProductSearchWidget({super.key, this.controller});

  @override
  State<ProductSearchWidget> createState() => _ProductSearchWidgetState();
}

class _ProductSearchWidgetState extends State<ProductSearchWidget> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: l10n.searchProducts,
        prefixIcon: const Icon(Icons.search),
        suffixIcon:
            widget.controller != null && widget.controller!.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      widget.controller!.clear();
                      context.read<PosBloc>().add(const SearchProducts(''));
                    },
                  )
                : null,
        border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      onSubmitted: (value) {
        if (value.isNotEmpty) {
          context.read<PosBloc>().add(AddProductBySku(value));
          widget.controller?.clear();
        }
      },
      onChanged: (value) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            context.read<PosBloc>().add(SearchProducts(value));
          }
        });
      },
    );
  }
}
