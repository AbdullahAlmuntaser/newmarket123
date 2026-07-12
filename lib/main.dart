import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supermarket/core/theme/app_theme.dart';
import 'package:supermarket/core/theme/theme_provider.dart';
import 'package:supermarket/core/theme/locale_provider.dart';
import 'package:supermarket/core/navigation/app_router.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart' as di;
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supermarket/native_sql_override.dart';
import 'package:supermarket/core/services/security_service.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:supermarket/presentation/widgets/navigation/command_palette.dart';

// Define a Intent for the Command Palette
class OpenCommandPaletteIntent extends Intent {
  const OpenCommandPaletteIntent();
}

void main() async {
  // 1. Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Apply native sqlite override as early as possible
  try {
    applyNativeSqlOverride();
    // Trigger the override callback NOW in the main isolate to actually
    // load SQLCipher and set isSqlCipherLoaded = true. Without this,
    // isSqlCipherLoaded stays false because the override callback is only
    // registered (not executed) by applyNativeSqlOverride().
    // The callback executes when openSqlite() is called, which normally
    // only happens in Drift's background isolate.
    sqlite3.sqlite3.openInMemory().dispose();
  } catch (e) {
    debugPrint('CRITICAL: Failed to load native SQL library: $e');
    runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 64),
                SizedBox(height: 16),
                Text("Critical System Error",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                    "Failed to load the database encryption library.\n"
                    "Please reinstall the app.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    ));
    return;
  }

  // 3. Pre-warm FlutterSecureStorage key fetch — must succeed
  try {
    await SecurityService.getDatabaseKey();
  } catch (e) {
    debugPrint('CRITICAL: Failed to initialize encryption key: $e');
    runApp(MaterialApp(
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                    "Failed to initialize the encryption key.\n"
                    "Please reinstall the app.\n\n$e",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    ));
    return;
  }

  // 4. Run the Initialization Wrapper as the Root
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
      debugPrint("INIT: Starting Dependency Injection...");
      // Perform DI initialization with a safer timeout
      await di.init().timeout(const Duration(seconds: 30));

      debugPrint("INIT: Verifying Database Connection...");
      final db = di.sl<AppDatabase>();

      await db.select(db.users).get().timeout(const Duration(seconds: 15));
      debugPrint("INIT: Database connection verified.");

      debugPrint("INIT: Loading Locale...");
      await di.sl<LocaleProvider>().loadLocale();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, stack) {
      final errStr = e.toString();
      debugPrint("FATAL INITIALIZATION ERROR: $errStr");
      debugPrintStack(stackTrace: stack);

      // Secondary recovery: if the error is an encryption/DB error,
      // delete the database file and retry once.
      if (errStr.contains('DATABASE_ENCRYPTION_ERROR') ||
          errStr.contains('code 26') ||
          errStr.contains('file is not a database')) {
        debugPrint("INIT: Database encryption error detected. Attempting file-level recovery...");
        try {
          final dbFolder = await getApplicationDocumentsDirectory();
          final file = File(p.join(dbFolder.path, 'app_db.sqlite'));
          if (await file.exists()) {
            final ts = DateTime.now().millisecondsSinceEpoch;
            final backupPath = "${file.path}.init_recovery_$ts";
            await file.copy(backupPath);
            await file.delete();
            debugPrint("INIT: Database file deleted. Backed up to $backupPath");
          }
          // Reset DI and retry
          if (sl.isRegistered<AppDatabase>()) {
            sl.unregister<AppDatabase>();
          }
          await di.init().timeout(const Duration(seconds: 30));
          final db2 = di.sl<AppDatabase>();
          await db2.select(db2.users).get().timeout(const Duration(seconds: 15));
          debugPrint("INIT: Recovery successful after file deletion.");
          if (mounted) {
            setState(() {
              _isInitialized = true;
              _error = "";
            });
          }
          return;
        } catch (retryErr) {
          debugPrint("INIT: Recovery also failed: $retryErr");
        }
      }

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
          return Shortcuts(
            shortcuts: <ShortcutActivator, Intent>{
              LogicalKeySet(
                      LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
                  const OpenCommandPaletteIntent(),
              LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
                  const OpenCommandPaletteIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                OpenCommandPaletteIntent:
                    CallbackAction<OpenCommandPaletteIntent>(
                  onInvoke: (intent) => _showCommandPalette(context),
                ),
              },
              child: MaterialApp.router(
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
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCommandPalette(BuildContext context) {
    final navigator = appRouter.routerDelegate.navigatorKey.currentState;
    if (navigator != null) {
      showDialog(
        context: navigator.context,
        builder: (context) => const CommandPalette(),
      );
    }
  }
}
