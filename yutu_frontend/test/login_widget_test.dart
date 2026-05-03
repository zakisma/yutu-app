import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
// Note: Ensure this matches your project name!
import 'package:yutu_frontend/screens/login_screen.dart';
import 'package:yutu_frontend/providers/auth_provider.dart';

void main() {
  Widget createLoginScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  group('Login Screen Widget Tests', () {
    testWidgets('Shows validation errors when submitting empty form', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen());

      // 1. Look for the translation KEY instead of the English word
      final loginButton = find.text('login_btn'); 
      expect(loginButton, findsOneWidget);

      // 2. Tap the button
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // 3. Look for the translation KEYS of the error messages
      expect(find.text('error_empty_email'), findsOneWidget);
      expect(find.text('error_empty_password'), findsOneWidget);
    });

    testWidgets('Email input field accepts text', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginScreen());

      final emailField = find.byType(TextFormField).first;

      await tester.enterText(emailField, 'test@aukro.cz');
      await tester.pump(); 

      expect(find.text('test@aukro.cz'), findsOneWidget);
    });
  });
}