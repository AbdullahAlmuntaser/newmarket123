import 'package:intl/intl.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/sales_dao.dart';
import 'package:supermarket/data/datasources/local/daos/purchases_dao.dart';
import 'package:supermarket/data/datasources/local/daos/products_dao.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart';

/// خدمة التقارير المالية والضريبية
/// Financial and Tax Reports Service
class FinancialReportsService {
  final AppDatabase database;
  late final SalesDao salesDao;
  late final PurchasesDao purchasesDao;
  late final ProductsDao productsDao;

  FinancialReportsService(this.database) {
    salesDao = SalesDao(database);
    purchasesDao = PurchasesDao(database);
    productsDao = ProductsDao(database);
  }

  /// تقرير ضريبة القيمة المضافة (VAT Report)
  /// Generates VAT report for a specific period
  Future<VATReport> generateVATReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Get sales invoices in period
      final salesInvoices = await salesDao.getInvoicesByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      // Get purchase invoices in period
      final purchaseInvoices = await purchasesDao.getInvoicesByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      double totalSalesExcludingVAT = 0.0;
      double totalVATCollected = 0.0; // VAT on sales
      double totalPurchasesExcludingVAT = 0.0;
      double totalVATPaid = 0.0; // VAT on purchases

      // Calculate sales VAT
      for (var invoice in salesInvoices) {
        final subtotal = invoice.total - invoice.tax;
        final tax = invoice.tax;

        totalSalesExcludingVAT += subtotal;
        totalVATCollected += tax;
      }

      // Calculate purchases VAT (PurchaseOrder doesn't have tax field)
      for (var invoice in purchaseInvoices) {
        final subtotal = invoice.total;
        const tax = 0.0; // PurchaseOrder doesn't have tax field

        totalPurchasesExcludingVAT += subtotal;
        totalVATPaid += tax;
      }

      final netVATPayable = totalVATCollected - totalVATPaid;

      return VATReport(
        startDate: startDate,
        endDate: endDate,
        totalSalesExcludingVAT: totalSalesExcludingVAT,
        totalVATCollected: totalVATCollected,
        totalPurchasesExcludingVAT: totalPurchasesExcludingVAT,
        totalVATPaid: totalVATPaid,
        netVATPayable: netVATPayable,
        salesInvoicesCount: salesInvoices.length,
        purchaseInvoicesCount: purchaseInvoices.length,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('فشل إنشاء تقرير VAT: ${e.toString()}');
    }
  }

  /// تقرير المبيعات التفصيلي
  /// Detailed Sales Report
  Future<SalesReport> generateSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    String? customerId,
    String? salespersonId,
  }) async {
    try {
      var invoices = await salesDao.getInvoicesByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      // Filter by customer if specified
      if (customerId != null) {
        invoices =
            invoices.where((inv) => inv.customerId == customerId).toList();
      }

      double totalRevenue = 0.0;
      double totalDiscount = 0.0;
      double totalTax = 0.0;
      double totalNet = 0.0;
      int totalQuantity = 0;

      for (var invoice in invoices) {
        final subtotal = invoice.total - invoice.tax;
        totalRevenue += subtotal;
        totalDiscount += invoice.discount;
        totalTax += invoice.tax;
        totalNet += invoice.total;
      }

      // Get items count
      for (var invoice in invoices) {
        final items = await salesDao.getInvoiceItems(invoice.id);
        for (var item in items) {
          totalQuantity += item.quantity.toInt();
        }
      }

      return SalesReport(
        startDate: startDate,
        endDate: endDate,
        totalRevenue: totalRevenue,
        totalDiscount: totalDiscount,
        totalTax: totalTax,
        totalNet: totalNet,
        totalQuantity: totalQuantity,
        invoicesCount: invoices.length,
        customerId: customerId,
        salespersonId: salespersonId,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('فشل إنشاء تقرير المبيعات: ${e.toString()}');
    }
  }

  /// تقرير المشتريات التفصيلي
  /// Detailed Purchase Report
  Future<PurchaseReport> generatePurchaseReport({
    required DateTime startDate,
    required DateTime endDate,
    String? supplierId,
  }) async {
    try {
      var invoices = await purchasesDao.getInvoicesByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      // Filter by supplier if specified
      if (supplierId != null) {
        invoices =
            invoices.where((inv) => inv.supplierId == supplierId).toList();
      }

      double totalPurchases = 0.0;
      double totalDiscount = 0.0;
      double totalTax = 0.0;
      double totalNet = 0.0;
      int totalQuantity = 0;

      for (var invoice in invoices) {
        totalPurchases += invoice.total;
        totalDiscount += 0.0; // PurchaseOrder doesn't have discount field
        totalTax += 0.0; // PurchaseOrder doesn't have tax field
        totalNet += invoice.total;
      }

      return PurchaseReport(
        startDate: startDate,
        endDate: endDate,
        totalPurchases: totalPurchases,
        totalDiscount: totalDiscount,
        totalTax: totalTax,
        totalNet: totalNet,
        totalQuantity: totalQuantity,
        invoicesCount: invoices.length,
        supplierId: supplierId,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('فشل إنشاء تقرير المشتريات: ${e.toString()}');
    }
  }

  /// تقرير الأرباح والخسائر المبسط
  /// Simplified Profit & Loss Report
  Future<ProfitLossReport> generateProfitLossReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Get sales revenue
      final salesReport = await generateSalesReport(
        startDate: startDate,
        endDate: endDate,
      );

      // Get purchase costs
      final purchaseReport = await generatePurchaseReport(
        startDate: startDate,
        endDate: endDate,
      );

      // Calculate gross profit
      final grossProfit =
          salesReport.totalRevenue - purchaseReport.totalPurchases;

      // Calculate operating expenses
      final accountingDao = AccountingDao(database);
      final expenseAccounts = await accountingDao.getAccountsByType('EXPENSE');
      double operatingExpenses = 0.0;
      for (final account in expenseAccounts) {
        // Exclude COGS account if it is considered an expense account (usually 5010)
        if (account.code != '5010') {
          operatingExpenses += await accountingDao.getAccountBalanceInRange(
            account.id,
            startDate,
            endDate,
          );
        }
      }

      final netProfit = grossProfit - operatingExpenses;

      return ProfitLossReport(
        startDate: startDate,
        endDate: endDate,
        totalRevenue: salesReport.totalRevenue,
        costOfGoodsSold: purchaseReport.totalPurchases,
        grossProfit: grossProfit,
        operatingExpenses: operatingExpenses,
        netProfit: netProfit,
        grossProfitMargin: salesReport.totalRevenue > 0
            ? (grossProfit / salesReport.totalRevenue * 100)
            : 0.0,
        netProfitMargin: salesReport.totalRevenue > 0
            ? (netProfit / salesReport.totalRevenue * 100)
            : 0.0,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('فشل إنشاء تقرير الأرباح والخسائر: ${e.toString()}');
    }
  }

  /// تقرير حركة المخزون
  /// Inventory Movement Report
  Future<InventoryMovementReport> generateInventoryMovementReport({
    required DateTime startDate,
    required DateTime endDate,
    String? productId,
  }) async {
    try {
      final movements = <InventoryMovement>[];

      // Get all inventory transactions in period
      // This would query the InventoryTransactions table
      // For now, we'll return a basic structure

      return InventoryMovementReport(
        startDate: startDate,
        endDate: endDate,
        productId: productId,
        movements: movements,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('فشل إنشاء تقرير حركة المخزون: ${e.toString()}');
    }
  }

  /// تصدير تقرير إلى CSV
  /// Export report to CSV format
  String exportToCSV<T>(T report) {
    final buffer = StringBuffer();

    if (report is VATReport) {
      buffer.writeln('تقرير ضريبة القيمة المضافة');
      buffer
          .writeln('من: ${DateFormat('yyyy-MM-dd').format(report.startDate)}');
      buffer.writeln('إلى: ${DateFormat('yyyy-MM-dd').format(report.endDate)}');
      buffer.writeln();
      buffer.writeln(
          'إجمالي المبيعات (بدون ضريبة),${report.totalSalesExcludingVAT}');
      buffer.writeln('إجمالي الضريبة المحصلة,${report.totalVATCollected}');
      buffer.writeln(
          'إجمالي المشتريات (بدون ضريبة),${report.totalPurchasesExcludingVAT}');
      buffer.writeln('إجمالي الضريبة المدفوعة,${report.totalVATPaid}');
      buffer.writeln('صافي الضريبة المستحقة,${report.netVATPayable}');
    } else if (report is SalesReport) {
      buffer.writeln('تقرير المبيعات');
      buffer
          .writeln('من: ${DateFormat('yyyy-MM-dd').format(report.startDate)}');
      buffer.writeln('إلى: ${DateFormat('yyyy-MM-dd').format(report.endDate)}');
      buffer.writeln();
      buffer.writeln('إجمالي الإيرادات,${report.totalRevenue}');
      buffer.writeln('إجمالي الخصومات,${report.totalDiscount}');
      buffer.writeln('إجمالي الضريبة,${report.totalTax}');
      buffer.writeln('صافي المبيعات,${report.totalNet}');
      buffer.writeln('عدد الفواتير,${report.invoicesCount}');
    }

    return buffer.toString();
  }
}

/// نموذج تقرير ضريبة القيمة المضافة
class VATReport {
  final DateTime startDate;
  final DateTime endDate;
  final double totalSalesExcludingVAT;
  final double totalVATCollected;
  final double totalPurchasesExcludingVAT;
  final double totalVATPaid;
  final double netVATPayable;
  final int salesInvoicesCount;
  final int purchaseInvoicesCount;
  final DateTime generatedAt;

  VATReport({
    required this.startDate,
    required this.endDate,
    required this.totalSalesExcludingVAT,
    required this.totalVATCollected,
    required this.totalPurchasesExcludingVAT,
    required this.totalVATPaid,
    required this.netVATPayable,
    required this.salesInvoicesCount,
    required this.purchaseInvoicesCount,
    required this.generatedAt,
  });

  String get formattedPeriod =>
      '${DateFormat('yyyy-MM-dd').format(startDate)} إلى ${DateFormat('yyyy-MM-dd').format(endDate)}';
}

/// نموذج تقرير المبيعات
class SalesReport {
  final DateTime startDate;
  final DateTime endDate;
  final double totalRevenue;
  final double totalDiscount;
  final double totalTax;
  final double totalNet;
  final int totalQuantity;
  final int invoicesCount;
  final String? customerId;
  final String? salespersonId;
  final DateTime generatedAt;

  SalesReport({
    required this.startDate,
    required this.endDate,
    required this.totalRevenue,
    required this.totalDiscount,
    required this.totalTax,
    required this.totalNet,
    required this.totalQuantity,
    required this.invoicesCount,
    this.customerId,
    this.salespersonId,
    required this.generatedAt,
  });
}

/// نموذج تقرير المشتريات
class PurchaseReport {
  final DateTime startDate;
  final DateTime endDate;
  final double totalPurchases;
  final double totalDiscount;
  final double totalTax;
  final double totalNet;
  final int totalQuantity;
  final int invoicesCount;
  final String? supplierId;
  final DateTime generatedAt;

  PurchaseReport({
    required this.startDate,
    required this.endDate,
    required this.totalPurchases,
    required this.totalDiscount,
    required this.totalTax,
    required this.totalNet,
    required this.totalQuantity,
    required this.invoicesCount,
    this.supplierId,
    required this.generatedAt,
  });
}

/// نموذج تقرير الأرباح والخسائر
class ProfitLossReport {
  final DateTime startDate;
  final DateTime endDate;
  final double totalRevenue;
  final double costOfGoodsSold;
  final double grossProfit;
  final double operatingExpenses;
  final double netProfit;
  final double grossProfitMargin;
  final double netProfitMargin;
  final DateTime generatedAt;

  ProfitLossReport({
    required this.startDate,
    required this.endDate,
    required this.totalRevenue,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.operatingExpenses,
    required this.netProfit,
    required this.grossProfitMargin,
    required this.netProfitMargin,
    required this.generatedAt,
  });
}

/// نموذج حركة مخزون
class InventoryMovement {
  final DateTime date;
  final String type; // IN, OUT, ADJUSTMENT
  final int quantity;
  final double unitCost;
  final String reference;
  final String? notes;

  InventoryMovement({
    required this.date,
    required this.type,
    required this.quantity,
    required this.unitCost,
    required this.reference,
    this.notes,
  });
}

/// نموذج تقرير حركة المخزون
class InventoryMovementReport {
  final DateTime startDate;
  final DateTime endDate;
  final String? productId;
  final List<InventoryMovement> movements;
  final DateTime generatedAt;

  InventoryMovementReport({
    required this.startDate,
    required this.endDate,
    this.productId,
    required this.movements,
    required this.generatedAt,
  });
}
