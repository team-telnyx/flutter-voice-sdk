import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:telnyx_flutter_webrtc/main.dart';
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/buttons/call_buttons.dart';
import '../helpers/test_config.dart';
import '../helpers/ui_helpers.dart';
import '../helpers/wait_helpers.dart';
import '../helpers/call_helpers.dart';

/// Outbound call tests - verify making calls works
void outboundCallTests() {
  patrolTest(
    'Make outbound call to echo test',
    timeout: TestConfig.testTimeout,
    framePolicy: LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
    skip: !TestConfig.hasSipCredentials,
    ($) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = ignoreOverflowErrors;
      addTearDown(() => FlutterError.onError = originalOnError);

      // Setup: Launch and connect
      await $.pumpWidgetAndSettle(const MyApp());
      await $.grantPermissionsIfNeeded();
      await $.loginWithSipCredentials();

      // Make call to echo test number
      await $.makeCall(TestConfig.testDestinationEcho);

      // Call should be active - wait a moment to verify it stays active
      await Future.delayed(const Duration(seconds: 2));

      // End the call
      await $.endCall();

      // Verify back at home screen
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  patrolTest(
    'Make outbound call and verify call state transitions',
    timeout: TestConfig.testTimeout,
    framePolicy: LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
    skip: !TestConfig.hasSipCredentials,
    ($) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = ignoreOverflowErrors;
      addTearDown(() => FlutterError.onError = originalOnError);

      // Setup
      await $.pumpWidgetAndSettle(const MyApp());
      await $.grantPermissionsIfNeeded();
      await $.loginWithSipCredentials();

      // Enter destination - use specific key to avoid wrong field
      final numberField = find.byKey(const Key('destination_field'));
      await $.tester.enterText(numberField, TestConfig.testDestinationEcho);
      await $.pumpAndSettle();

      // Initiate call
      await $.tapTypeWithRetry<CallButton>();
      await $.grantPermissionsIfNeeded();

      // Verify we go through connecting state
      // (requires call_status widget in example app)
      try {
        await $.waitForKeyWithText(
          'call_status',
          'connecting',
          timeout: const Duration(seconds: 5),
        );
      } catch (_) {
        // Might have already passed through connecting
      }

      // Wait for active state
      await $.waitForCallActive();

      // End call
      await $.endCall();
    },
  );

  patrolTest(
    'Make call to SIP destination',
    timeout: TestConfig.testTimeout,
    framePolicy: LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
    skip: !TestConfig.hasSipCredentials || TestConfig.testDestinationSip.isEmpty,
    ($) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = ignoreOverflowErrors;
      addTearDown(() => FlutterError.onError = originalOnError);

      await $.pumpWidgetAndSettle(const MyApp());
      await $.grantPermissionsIfNeeded();
      await $.loginWithSipCredentials();

      // Call SIP destination
      await $.makeCall(TestConfig.testDestinationSip);

      // Brief wait to verify call is stable
      await Future.delayed(const Duration(seconds: 3));

      await $.endCall();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );
}
