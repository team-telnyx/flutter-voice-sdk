import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telnyx_flutter_webrtc/main.dart' as app;
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/buttons/call_buttons.dart';

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
      await tester.enterText(
        find.widgetWithText(TextFormField, 'SIP Username'),
        username,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'SIP Password'),
        password,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Caller ID Name'),
        'Flutter Integration Test User',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Caller ID Number'),
        number,
      );

      // Save user
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      // Select user from bottom sheet
      await tester.tap(find.text(username));
      await tester.pumpAndSettle();

      // Wait for connection
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Enter number to call
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Destination'),
        '18004377950',
      );
      await tester.pumpAndSettle();

      // Make call
      await tester.tap(find.byType(CallButton));
      await tester.pumpAndSettle();

      // Wait for call to be established
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Test mute functionality
      final muteButton = find.byIcon(Icons.mic_off);
      await tester.tap(muteButton);
      await tester.pumpAndSettle();
      await tester.tap(muteButton);
      await tester.pumpAndSettle();

      // Test DTMF
      final keypadButton = find.byIcon(Icons.dialpad);
      await tester.tap(keypadButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      // End call
      await tester.tap(find.byIcon(Icons.call_end));
      await tester.pumpAndSettle();

      // Verify we're back at the home screen
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}