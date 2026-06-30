import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_state.dart';
import 'package:supermarket/presentation/features/pos/widgets/pos_product_card.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        if (state is PosLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is PosLoaded) {
          final isSearching = state.searchQuery.isNotEmpty;
          final products = isSearching ? state.searchResults : state.filteredProducts;

          if (products.isEmpty) {
            return Center(
              child: Text(isSearching
                  ? 'لا توجد منتجات تطابق بحثك'
                  : 'لا يوجد منتجات في هذه الفئة'),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1100
                  ? 5
                  : width >= 760
                      ? 4
                      : width >= 520
                          ? 3
                          : 2;
              final childAspectRatio = width < 520 ? 0.88 : 0.82;

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return PosProductCard(
                    product: product,
                    onTap: () {
                      context.read<PosBloc>().add(AddProductBySku(product.sku));
                    },
                  );
                },
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
