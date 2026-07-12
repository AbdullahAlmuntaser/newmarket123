import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quotation_provider.dart';

class QuotationListScreen extends StatelessWidget {
  const QuotationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عروض الأسعار'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to create quotation screen
            },
          ),
        ],
      ),
      body: Consumer<QuotationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(child: Text('Error: ${provider.error}'));
          }

          if (provider.quotations.isEmpty) {
            return const Center(child: Text('لا توجد عروض أسعار'));
          }

          return ListView.builder(
            itemCount: provider.quotations.length,
            itemBuilder: (context, index) {
              final quotation = provider.quotations[index];
              return ListTile(
                title: Text(quotation.quotationNumber),
                subtitle: Text('Customer ID: ${quotation.customerId}'),
                trailing: Chip(
                  label: Text(quotation.status),
                  backgroundColor: _getStatusColor(quotation.status),
                ),
                onTap: () {
                  // Navigate to quotation details
                },
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
