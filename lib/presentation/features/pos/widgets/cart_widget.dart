import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_state.dart';

class CartWidget extends StatelessWidget {
  const CartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BlocBuilder<PosBloc, PosState>(
          builder: (context, state) {
            if (state is! PosLoaded) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.cart,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.cart.length,
                    itemBuilder: (context, index) {
                      final item = state.cart[index];
                      return ListTile(
                        title: Text(item.product.name),
                        subtitle: Text(
                            '${item.quantity} x ${item.unitPrice.toStringAsFixed(2)}'),
                        trailing: Text(
                          item.total.toStringAsFixed(2),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.total,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      state.total.toStringAsFixed(2),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  child: Text(l10n.checkout),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
