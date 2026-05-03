import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/theme/app_theme.dart';
import 'package:supermarket/core/theme/theme_provider.dart';
import 'package:supermarket/core/navigation/app_router.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart' as di;
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supermarket/presentation/features/accounting/accounting_provider.dart';
import 'package:supermarket/presentation/features/products/products_provider.dart';
import 'package:supermarket/presentation/features/purchases/purchase_provider.dart';
import 'package:supermarket/presentation/features/accounting/shifts_provider.dart';
import 'package:supermarket/presentation/features/hr/hr_provider.dart';
import 'package:supermarket/presentation/features/hr/payroll_provider.dart';
import 'package:supermarket/presentation/features/inventory/stock_transfer_provider.dart';
import 'package:supermarket/presentation/features/accounting/asset_provider.dart';
import 'package:supermarket/presentation/features/customers/customer_statement_provider.dart';
import 'package:supermarket/core/services/shift_service.dart';
import 'package:supermarket/core/services/hr_service.dart';
import 'package:supermarket/core/services/stock_transfer_service.dart';
import 'package:supermarket/core/services/asset_service.dart';
import 'package:supermarket/core/services/posting_engine.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RootWidget());
}

class RootWidget extends StatelessWidget {
  const RootWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. täkɊ anõ talttbuiq ybdō b  MaterialApp yahtawi alà Navigator
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = "gari althamil...";
  String _detailStatus = "";
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    // 2. la tastakhdam Navigator mubasharatan fi initState�  nus