import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/theme/theme_provider.dart';
import 'package:supermarket/core/theme/locale_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart' as di;

void main() async {
  // 1. Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Run the Initialization Wrapper as the Root
  runApp(const AppRoot());
}

/// The AppRoot manages the high-level state of the application:
/// - Uninitialized: Shows the SplashScreen
/// - Initialized: Shows the main MyApp with GoRouter
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _isInitialized = false;
  String _error = "";

  @override
  void initState() {
    super.initState();
    _performInitialization();
  }

  Future<void> _performInitialization() async {
    try {
      // Perform DI initialization
      await di.init();

      // Additional database health check
      final db = di.sl<AppDatabase>();
      await db.select(db.users).get().timeout(const Duration(seconds: 5));
      await db.seedSecurityData();
      await db.ensureAccountingPeriodsForYear(DateTime.now().year);
      await di.sl<LocaleProvider>().loadLocale();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("FATAL INITIALIZATION ERROR: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If an error occurred during initialization, show a global error screen
    if (_error.isNotEmpty) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text("Critical System Error",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = "";
                        _isInitialized = false;
                      });
                      _performInitialization();
                    },
                    child: const Text("Retry Initialization"),
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }

    // If not initialized yet, show the SplashScreen
    if (!_isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    }

    // Once initialized, show the real MyApp
    return const MyApp();
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance, size: 100, color: Colors.teal),
            SizedBox(height: 40),
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              "جاري تهيئة النظام...",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal),
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
      providers: di.buildAppProviders(),
      child: Builder(
        builder: (context) {
          final themeProvider = Provider.of<ThemeProvider>(context);
          final localeProvider = Provider.of<LocaleProvider>(context);
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
            locale: localeProvider.locale,
          );
        },
      ),
    );
  }
}
