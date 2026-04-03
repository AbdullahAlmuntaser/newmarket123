import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: ListView.builder(
        itemCount: 20, // Placeholder for 20 inventory items
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.shopping_cart), // Placeholder icon
            title: Text('Item ${index + 1}'),
            subtitle: const Text('Stock: 10'), // Placeholder stock
            trailing: const Text('\$19.99'), // Placeholder price
          );
        },
      ),
    );
  }
}
