import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Primary Palette ───
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color secondary = Color(0xFF00897B);
  static const Color secondaryLight = Color(0xFF4DB6AC);

  // ─── Semantic Colors ───
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFFA726);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color error = Color(0xFFEF5350);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF42A5F5);
  static const Color infoLight = Color(0xFFE3F2FD);

  // ─── Category Card Colors ───
  static const Color cardSales = Color(0xFFE3F2FD);
  static const Color cardSalesIcon = Color(0xFF1565C0);
  static const Color cardPurchases = Color(0xFFE8F5E9);
  static const Color cardPurchasesIcon = Color(0xFF388E3C);
  static const Color cardInventory = Color(0xFFFFF3E0);
  static const Color cardInventoryIcon = Color(0xFFEF6C00);
  static const Color cardCash = Color(0xFFE0F2F1);
  static const Color cardCashIcon = Color(0xFF00897B);
  static const Color cardCustomers = Color(0xFFEDE7F6);
  static const Color cardCustomersIcon = Color(0xFF5E35B1);
  static const Color cardSuppliers = Color(0xFFFBE9E7);
  static const Color cardSuppliersIcon = Color(0xFFD84315);
  static const Color cardAlert = Color(0xFFFFEBEE);
  static const Color cardAlertIcon = Color(0xFFC62828);

  // ─── Operation Category Colors ───
  static const Color opSales = Color(0xFF1E88E5);
  static const Color opPurchases = Color(0xFF43A047);
  static const Color opCustomers = Color(0xFF7E57C2);
  static const Color opSuppliers = Color(0xFFE53935);
  static const Color opInventory = Color(0xFFFB8C00);
  static const Color opCashbox = Color(0xFF00ACC1);
  static const Color opReports = Color(0xFF546E7A);

  // ─── Section Backgrounds ───
  static const Color sectionBg = Color(0xFFF5F7FA);
  static const Color sectionBgAlt = Color(0xFFFAFBFC);
  static const Color attentionBg = Color(0xFFFFFDE7);
  static const Color attentionBorder = Color(0xFFFFD54F);
  static const Color timelineBg = Color(0xFFF8F9FA);

  // ─── Chart Colors ───
  static const List<Color> chartPalette = [
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFFE53935),
    Color(0xFF7E57C2),
    Color(0xFF00ACC1),
    Color(0xFF546E7A),
  ];

  // ─── Gradient Presets ───
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF388E3C), Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFEF6C00), Color(0xFFFFB74D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFC62828), Color(0xFFEF5350)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
