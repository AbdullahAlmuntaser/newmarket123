import 'package:flutter/material.dart';

class PurchaseDetailsPage extends StatelessWidget {
  final String purchaseId;
  const PurchaseDetailsPage({super.key, required this.purchaseId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Purchase Details')),
      body: Center(child: Text('Purchase ID: $purchaseId')),
    );
  }
}
