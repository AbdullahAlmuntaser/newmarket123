import 'package:flutter/foundation.dart';
import '../../domain/entities/sales_invoice.dart';
import 'transaction_engine.dart';
import 'posting_engine.dart';
import 'app_settings_service.dart';
import 'permission_service.dart';
import '../../data/datasources/local/app_database.dart';

class SalesService {
  final AppDatabase db;
  final PostingEngine postingEngine;
  final AppSettingsService settings;
  final PermissionService permissions;
  final TransactionEngine transactionEngine;

  SalesService(this.db, this.postingEngine,
      this.settings, this.permissions, this.transactionEngine);

  @Deprecated('استخدم TransactionEngine.postSale بدلاً من ذلك')
  Future<void> processInvoice(SalesInvoice invoice, String userId) async {
    await permissions.executeIfAllowed(
      userId,
      PermissionCode.postSale,
      () async {
        try {
          await transactionEngine.postSale(invoice.id, userId: userId);
        } on Exception catch (e) {
          debugPrint('خطأ في معالجة الفاتورة ${invoice.id}: $e');
          rethrow;
        }
      },
    );
  }
}
