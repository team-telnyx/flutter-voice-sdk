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
      // 1. Start the app
      await app.main();
      await tester.pumpAndSettle();

      // 2. Open the bottom sheet by pressing "Switch Profile"
      await tester.tap(find.text('Switch Profile'));
      await tester.pumpAndSettle();

      // 3. Tap "Add new profile" to show the add-profile form
      await tester.tap(find.text('Add new profile'));
      await tester.pumpAndSettle();

      // 4. Retrieve credentials from environment variables
      final username =
          const String.fromEnvironment('APP_LOGIN_USER', defaultValue: '');
      final password =
          const String.fromEnvironment('APP_LOGIN_PASSWORD', defaultValue: '');
      final number =
          const String.fromEnvironment('APP_LOGIN_NUMBER', defaultValue: '');

      // 5. Fill in SIP details in the bottom sheet
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

      // 6. Save the new profile
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // 7. Tap "Confirm" to close the bottom sheet (if needed)
      final confirmButton = find.text('Confirm');
      if (confirmButton.evaluate().isNotEmpty) {
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();
      }

      // 8. Now tap "Connect" on the main screen if your UI requires a manual connect:
      final connectButton = find.text('Connect');
      if (connectButton.evaluate().isNotEmpty) {
        await tester.tap(connectButton);
        await tester.pumpAndSettle();
      }

      // 9. Wait a bit for the SIP connection to establish
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 10. Enter the number to call
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Destination'),
        '18004377950',
      );
      await tester.pumpAndSettle();

      // 11. Make the call
      await tester.tap(find.byType(CallButton));
      await tester.pumpAndSettle();

      // 12. Wait for call to be established
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // 13. Test Hold/Unhold (tap pause on/off)
      final holdButton = find.byIcon(Icons.pause);
      await tester.tap(holdButton);
      await tester.pumpAndSettle();
      await tester.tap(holdButton);
      await tester.pumpAndSettle();

      // 14. Test DTMF (open keypad & press digits)
      final keypadButton = find.byIcon(Icons.dialpad);
      await tester.tap(keypadButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      // close the keypad
      final closeKeypadButton = find.byIcon(Icons.close);
      await tester.tap(closeKeypadButton);
      await tester.pumpAndSettle();

      // 15. End call
      await tester.tap(find.byIcon(Icons.call_end));
      await tester.pumpAndSettle();

      // 16. Verify we're back at the home screen
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
