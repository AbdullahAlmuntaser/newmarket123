import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/main.dart'; // Assuming MyApp is here
import 'package:supermarket/presentation/features/auth/login_page.dart';
import 'package:drift/native.dart';

void main() {
  late AppDatabase appDatabase;
  late AuthProvider authProvider;
  // late AccountingService accountingService;
  late SharedPreferences prefs;

  // This setup runs once before all tests
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    
    // Use an in-memory database for testing
    appDatabase = AppDatabase(NativeDatabase.memory());

    // Correctly initialize providers
    authProvider = AuthProvider(prefs); 
    // accountingService = AccountingService(appDatabase); 

    // Seed the database with necessary data if needed
    // await accountingService.seedDefaultAccounts(); 
  });

  // Clean up after all tests
  tearDownAll(() {
    appDatabase.close();
  });

  testWidgets('Login Screen Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: appDatabase),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          // Provider<AccountingService>.value(value: accountingService),
          Provider<SharedPreferences>.value(value: prefs),
        ],
        child: const MyApp(), // MyApp will use the providers
      ),
    );

    // The app can take a moment to build the first frame
    await tester.pumpAndSettle();

    // The app starts with the LoginScreen. Let's verify that.
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Supermarket POS'), findsOneWidget);
    
    // Also check for some widgets inside LoginPage
    expect(find.byType(TextFormField), findsNWidgets(2)); // email and password
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}