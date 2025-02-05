import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:telnyx_flutter_webrtc/main.dart';
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/buttons/call_buttons.dart';

void main() {
  patrolTest(
    'Full call flow test',
    framePolicy: LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
    ($) async {
      // 1. Start the app using Patrol
      await $.pumpWidgetAndSettle(const MyApp());
      await $.native.grantPermissionWhenInUse();

      // 2. Open the bottom sheet by pressing "Switch Profile"
      await $('Switch Profile').tap();
      await $.pumpAndSettle();

      // 3. Tap "Add new profile"
      await $('Add new profile').tap();
      await $.pumpAndSettle();

      // 4. Retrieve credentials from environment variables
      final username = const String.fromEnvironment(
        'APP_LOGIN_USER',
        defaultValue: 'testUser',
      );
      final password = const String.fromEnvironment(
        'APP_LOGIN_PASSWORD',
        defaultValue: 'testPassword',
      );
      final number = const String.fromEnvironment(
        'APP_LOGIN_NUMBER',
        defaultValue: 'testNumber',
      );

      // 5. Fill in SIP details in the bottom sheet
      await $(TextFormField).at(0).enterText(username);
      await $(TextFormField).at(1).enterText(password);
      await $(TextFormField).at(2).enterText('Flutter Integration Test User');
      await $(TextFormField).at(3).enterText(number);

      // 6. Save the new profile
      await $('Save').tap();
      await $.pumpAndSettle();

      // 7. Select the newly added profile by tapping its display text
      await $('Flutter Integration Test User').tap();
      await $.pumpAndSettle();

      // 8. Tap "Confirm" to close bottom sheet, if it's present
      final confirmButton = $('Confirm');
      if (confirmButton.exists) {
        await confirmButton.tap();
        await $.pumpAndSettle();
      }

      // 9. Tap "Connect" if your UI requires a manual connect
      final connectButton = $('Connect');
      if (connectButton.exists) {
        await connectButton.tap();
        await $.pumpAndSettle();
      }

      // 10. Wait a bit for the SIP connection
      await Future.delayed(const Duration(seconds: 5));
      await $.pumpAndSettle();

      // 11. Enter the number to call
      await $(TextFormField).at(0).enterText('18004377950');
      await $.pumpAndSettle();

      // 12. Make the call
      // CallButton is a custom widget, so we'll use $.tester.tap(find.byType(...))
      await $.tester.tap(find.byType(CallButton));
      await $.pumpAndSettle();
      await $.native.grantPermissionWhenInUse();

      // 13. Wait for call to be established
      await Future.delayed(const Duration(seconds: 10));
      await $.pumpAndSettle();

      // 14. Test Hold/Unhold (tap pause on/off)
      await $.tester.tap(find.byIcon(Icons.pause));
      await $.pumpAndSettle();
      await $.tester.tap(find.byIcon(Icons.play_arrow));
      await $.pumpAndSettle();

      // 15. Test DTMF (open keypad & press digits)
      await $.tester.tap(find.byIcon(Icons.dialpad));
      await $.pumpAndSettle();
      // You can tap digits by text, if they're displayed as text:
      await $('1').tap();
      await $.pumpAndSettle();
      await $('2').tap();
      await $.pumpAndSettle();
      await $('3').tap();
      await $.pumpAndSettle();

      // Close the keypad
      await $.tester.tap(find.byIcon(Icons.close));
      await $.pumpAndSettle();

      // 16. End call
      await $.tester.tap(find.byType(DeclineButton));
      await $.pumpAndSettle();

      // 17. Verify we're back at HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );
}
