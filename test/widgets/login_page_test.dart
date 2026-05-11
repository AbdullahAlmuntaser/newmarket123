import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/presentation/features/auth/login_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  late MockAuthProvider mockAuthProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    when(() => mockAuthProvider.seedAdmin()).thenAnswer((_) async {});
    when(() => mockAuthProvider.hasUsers()).thenAnswer((_) async => true);
    when(() => mockAuthProvider.login(any(), any()))
        .thenAnswer((_) async => true);
  });

  Widget createTestWidget({Widget? child}) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ar'),
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: mockAuthProvider,
        child: child ?? const LoginPage(),
      ),
    );
  }

  group('LoginPage Widget Tests', () {
    testWidgets(
      'displays login form with text fields and button',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsNWidgets(2));
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byIcon(Icons.account_balance), findsOneWidget);
      },
    );

    testWidgets('has username and password text fields', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final textFields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.length, equals(2));

      final passwordField = textFields.last;
      expect(passwordField.obscureText, isTrue);
    });

    testWidgets('login button has teal background color', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.style?.backgroundColor?.resolve({}), equals(Colors.teal));
    });

    testWidgets('can enter text in username field', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'admin');
      expect(find.text('admin'), findsOneWidget);
    });

    testWidgets('shows initial admin setup when no users exist', (tester) async {
      when(() => mockAuthProvider.hasUsers()).thenAnswer((_) async => false);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('تهيئة المسؤول الأول'), findsOneWidget);
      expect(find.text('إنشاء المسؤول والدخول'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));
    });
  });
}