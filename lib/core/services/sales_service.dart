import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../../domain/entities/sales_invoice.dart';
import 'posting_engine.dart';
import 'inventory_service.dart';
import 'app_settings_service.dart';
import 'permission_service.dart';
import '../../data/datasources/local/app_database.dart';

class SalesService {
  final AppDatabase db;
  final PostingEngine postingEngine;
  final InventoryService inventoryService;
  final AppSettingsService settings;
  final PermissionService permissions;

  SalesService(this.db, this.postingEngine, this.inventoryService,
      this.settings, this.permissions);

  Future<void> processInvoice(SalesInvoice invoice, String userId) async {
    // التحقق من الصلاحية قبل تنفيذ العملية
    await permissions.executeIfAllowed(userId, 'CREATE_SALE', () async {
      try {
        await db.transaction(() async {
          // جلب الإعدادات (المستودع فقط)
          final warehouseId =
              await settings.getCurrentWarehouseId() ?? "MAIN_WAREHOUSE";

          // حساب الإجماليات (استخدام الضريبة من الفاتورة مباشرة)
          double subtotal = 0;
          for (var item in invoice.items) {
            subtotal += (item.quantity * item.unitFactor * item.price);
          }

          double discount = invoice.discount;
          double tax = invoice.taxAmount; // استخدام القيمة الصحيحة
          double total = subtotal - discount + tax;

          // 1. خصم الكميات من المخزون
          for (var item in invoice.items) {
            try {
              await inventoryService.deductStock(
                itemId: item.itemId,
                quantity: item.quantity * item.unitFactor,
                warehouseId: warehouseId,
                referenceId: invoice.id,
                userId: userId,
              );
            } catch (e) {
              throw Exception('فشل في تحديث المخزون للصنف ${item.itemId}: $e');
            }
          }

          // 2. القيد المحاسبي
          await postingEngine.postEntry(
            entries: [
              PostingLine(
                account: invoice.paymentMethod == 'cash'
                    ? 'CASH_BOX'
                    : 'CUSTOMER_AR',
                debit: total,
                credit: 0,
              ),
              PostingLine(
                account: 'SALES_REVENUE',
                debit: 0,
                credit: subtotal - discount,
              ),
              if (tax > 0)
                PostingLine(
                  account: 'VAT_PAYABLE',
                  debit: 0,
                  credit: tax,
                ),
            ],
            reference: "INV_${invoice.id}",
            date: invoice.timestamp,
          );

          // 3. Audit Log
          await db.into(db.auditLogs).insert(
                AuditLogsCompanion.insert(
                  userId: Value(userId),
                  action: 'PROCESS_INVOICE',
                  targetEntity: 'SalesInvoice',
                  entityId: invoice.id,
                  details: Value(
                      'تم معالجة فاتورة المبيعات رقم ${invoice.id} بقيمة $total'),
                  timestamp: Value(DateTime.now()),
                ),
              );
        });
      } on Exception catch (e) {
        debugPrint('خطأ في معالجة الفاتورة ${invoice.id}: $e');
        rethrow;
      }
    });
  }
}
