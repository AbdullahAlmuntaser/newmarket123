import 'package:flutter/material.dart';

class NewPurchasePage extends StatelessWidget {
  const NewPurchasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase')),
      body: const Center(child: Text('New Purchase Page')),
    );
  }
}
