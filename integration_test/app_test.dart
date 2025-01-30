import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telnyx_flutter_webrtc/main.dart' as app;
import 'package:telnyx_flutter_webrtc/screens/home_screen.dart';
import 'package:telnyx_flutter_webrtc/screens/login_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Test', () {
    testWidgets('Full call flow test', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Create user with debug mode
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Get credentials from environment variables
      final username = String.fromEnvironment('APP_LOGIN_USER', defaultValue: '');
      final password = String.fromEnvironment('APP_LOGIN_PASSWORD', defaultValue: '');
      final number = String.fromEnvironment('APP_LOGIN_NUMBER', defaultValue: '');

      // Fill in user details
      await tester.enterText(find.byKey(const Key('username_field')), username);
      await tester.enterText(find.byKey(const Key('password_field')), password);
      await tester.enterText(find.byKey(const Key('number_field')), number);
      await tester.enterText(find.byKey(const Key('name_field')), 'Flutter Integration Test User');
      
      // Enable debug mode
      await tester.tap(find.byKey(const Key('debug_switch')));
      await tester.pumpAndSettle();

      // Save user
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Select user from bottom sheet
      await tester.tap(find.text(username));
      await tester.pumpAndSettle();

      // Wait for connection
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Enter number to call
      await tester.enterText(find.byKey(const Key('phone_number_field')), '18004377950');
      await tester.pumpAndSettle();

      // Make call
      await tester.tap(find.byKey(const Key('call_button')));
      await tester.pumpAndSettle();

      // Wait for call to be established
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Test mute functionality
      await tester.tap(find.byKey(const Key('mute_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mute_button')));
      await tester.pumpAndSettle();

      // Test DTMF
      await tester.tap(find.byKey(const Key('keypad_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      // End call
      await tester.tap(find.byKey(const Key('end_call_button')));
      await tester.pumpAndSettle();

      // Verify we're back at the home screen
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}