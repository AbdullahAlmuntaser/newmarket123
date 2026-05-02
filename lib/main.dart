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
  
  runApp(const SplashScreen());
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await di.init();
      
      final authProvider = di.sl<AuthProvider>();
      await authProvider.seedAdmin();
      
      final accountingService = di.sl<AccountingService>();
      await accountingService.seedDefaultAccounts();
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MyApp()),
        );
      }
    } catch (e, stack) {
      debugPrint("Critical startup error: $e");
      debugPrint(stack.toString());
      if (mounted) {
        _showError(e.toString());
      }
    }
  }

  void _showError(String error) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'خطأ في تشغيل التطبيق',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(error, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => main(),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store, size: 80, color: Colors.teal),
              SizedBox(height: 24),
              Text(
                'نظام سوبرماركت',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري التحميل...'),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>(create: (_) => di.sl<AppDatabase>()),
        Provider<AccountingService>(create: (_) => di.sl<AccountingService>()),
        ChangeNotifierProvider(create: (_) => di.sl<ThemeProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<AuthProvider>()),
        ChangeNotifierProvider(create: (_) => AccountingProvider(di.sl<AppDatabase>())),
        ChangeNotifierProvider(create: (_) => di.sl<ProductsProvider>()),
        ChangeNotifierProvider(
          create: (_) => PurchaseProvider(di.sl<AppDatabase>(), di.sl<PurchaseService>()),
        ),
        ChangeNotifierProvider(create: (_) => ShiftProvider(ShiftService(di.sl<AppDatabase>()))),
        ChangeNotifierProvider(create: (_) => HRProvider(HRService(di.sl<AppDatabase>(), di.sl<PostingEngine>()))),
        ChangeNotifierProvider(create: (_) => PayrollProvider(HRService(di.sl<AppDatabase>(), di.sl<PostingEngine>()))),
        ChangeNotifierProvider(
          create: (_) => StockTransferProvider(StockTransferService(di.sl<AppDatabase>())),
        ),
        ChangeNotifierProvider(create: (_) => AssetProvider(AssetService(di.sl<AppDatabase>()))),
        ChangeNotifierProvider(create: (_) => CustomerStatementProvider()),
      ],
      child: Builder(
        builder: (context) {
          final themeProvider = Provider.of<ThemeProvider>(context);
          return MaterialApp.router(
            title: 'Supermarket ERP',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: appRouter,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ar'),
          );
        },
      ),
    );
  }
}
