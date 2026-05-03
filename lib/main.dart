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
  String _status = "جاري التحميل...";
  String _detailStatus = "";
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    try {
      // Global timeout for initialization
      await Future.any([
        _initializeApp(),
        Future.delayed(const Duration(seconds: 25), () {
          throw Exception("Initialization timed out after 25 seconds");
        }),
      ]);
    } catch (e, stack) {
      debugPrint("FATAL INITIALIZATION ERROR: $e");
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        _showError("خطأ حرج في تشغيل التطبيق: $e");
      }
    }
  }

  void _updateStatus(String status, [String detail = ""]) {
    if (mounted) {
      setState(() {
        _status = status;
        _detailStatus = detail;
      });
    }
  }

  Future<void> _initializeApp() async {
    try {
      _updateStatus("جاري تهيئة الخدمات...", "1/4");
      await di.init();
      
      _updateStatus("جاري فتح قاعدة البيانات...", "2/4");
      final db = di.sl<AppDatabase>();
      
      _updateStatus("جاري فحص قاعدة البيانات...", "3/4");
      try {
        // Just trigger a simple query to ensure connection
        await db.select(db.users).get().timeout(const Duration(seconds: 10));
        _updateStatus("✓ تم الاتصال بقاعدة البيانات", "4/4");
      } catch (e) {
        debugPrint("DB CHECK WARNING: $e");
        _updateStatus("⚠ تنبيه: مشكلة في فحص قاعدة البيانات", "سيتم المحاولة على أي حال");
        await Future.delayed(const Duration(seconds: 1));
      }
      
      _updateStatus("جاري التحميل النهائي...", "✅");
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        _navigateToMain();
      }
    } catch (e, stack) {
      debugPrint("INITIALIZATION STEP ERROR: $e");
      debugPrintStack(stackTrace: stack);
      rethrow; // Caught by _startInitialization
    }
  }

  void _navigateToMain() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    debugPrint("NAVIGATE: Transitioning to MyApp");
    
    // Use the RootWidget's Navigator context
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MyApp()),
    );
  }

  void _showError(String error) {
    debugPrint("SHOW_ERROR: $error");
    if (!mounted) return;

    _updateStatus("⚠ حدث خطأ", error);

    // After a delay, show a dialog or button to try anyway
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("تنبيه"),
            content: Text(error),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startInitialization();
                },
                child: const Text("إعادة المحاولة"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToMain();
                },
                child: const Text("الدخول على أي حال"),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Return only Scaffold here, RootWidget provides MaterialApp
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade50, Colors.white],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance, size: 100, color: Colors.teal),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            if (_detailStatus.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _detailStatus,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 40),
            const Text(
              "نظام إدارة السوبر ماركت",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
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
          debugPrint("MYAPP: Building MaterialApp.router");
          final themeProvider = Provider.of<ThemeProvider>(context);
          debugPrint("MYAPP: ThemeProvider gotten: ${themeProvider.themeMode}");
          debugPrint("MYAPP: Building router config");
          
          return MaterialApp.router(
            title: 'Supermarket ERP',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: appRouter,
            debugShowCheckedModeBanner: false,
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
