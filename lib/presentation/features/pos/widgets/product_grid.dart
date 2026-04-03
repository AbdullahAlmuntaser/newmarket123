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
          final products = state.filteredProducts;

          if (products.isEmpty) {
            return const Center(child: Text('لا يوجد منتجات في هذه الفئة'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.75,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
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
        }

        return const SizedBox.shrink();
      },
    );
  }
}
