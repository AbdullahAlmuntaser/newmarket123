import 'package:flutter/material.dart';

class BudgetsPage extends StatelessWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الميزانيات التقديرية'),
      ),
      body: const Center(
        child: Text('ميزة الميزانيات التقديرية قيد التطوير'),
      ),
    );
  }
}