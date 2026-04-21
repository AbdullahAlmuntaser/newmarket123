import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/main.dart';
import 'package:supermarket/presentation/features/auth/login_page.dart';
import 'package:drift/native.dart';
import 'package:supermarket/injection_container.dart' as di;
import 'package:supermarket/core/theme/theme_provider.dart';
import 'package:supermarket/presentation/features/products/products_provider.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:supermarket/core/services/role_permissions_service.dart';

void main() {
  late AppDatabase appDatabase;
  late AuthProvider authProvider;
  late AccountingService accountingService;
  late EventBusService eventBus;
  late SharedPreferences prefs;
  late PermissionsService permissionsService;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    appDatabase = AppDatabase(NativeDatabase.memory());
    permissionsService = PermissionsService(appDatabase);
    authProvider = AuthProvider(appDatabase, permissionsService);
    eventBus = EventBusService();
    accountingService = AccountingService(appDatabase, eventBus);

    // Register in GetIt for MyApp to find them
    await di.sl.reset(); // Await reset to ensure it's finished
    di.sl.registerLazySingleton(() => appDatabase);
    di.sl.registerLazySingleton(() => authProvider);
    di.sl.registerLazySingleton(() => eventBus);
    di.sl.registerLazySingleton(() => accountingService);
    di.sl.registerLazySingleton(() => permissionsService);
    di.sl.registerLazySingleton(() => ThemeProvider());
    di.sl.registerLazySingleton(() => ProductsProvider(appDatabase));
    di.sl.registerLazySingleton(() => prefs);
  });

  tearDownAll(() {
    appDatabase.close();
    eventBus.dispose();
  });

  testWidgets('Login Screen Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: appDatabase),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          Provider<AccountingService>.value(value: accountingService),
          Provider<SharedPreferences>.value(value: prefs),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    // The app is hardcoded to 'ar' locale in main.dart
    expect(find.text('نظام المحاسبة'), findsOneWidget);

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
