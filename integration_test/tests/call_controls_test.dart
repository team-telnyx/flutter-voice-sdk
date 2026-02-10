import 'package:test/test.dart';
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

/// Call control tests - hold, mute, speaker, DTMF
void callControlsTests() {
  patrolTest(
    'Hold and unhold call',
    timeout: Timeout(TestConfig.testTimeout),
    framePolicy: LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
    skip: !TestConfig.hasSipCredentials,
    ($) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = ignoreOverflowErrors;
      addTearDown(() => FlutterError.onError = originalOnError);

      // Setup: Connect and make call
      await $.pumpWidgetAndSettle(const MyApp());
      await $.grantPermissionsIfNeeded();
      await $.loginWithSipCredentials();
      await $.makeCall(TestConfig.testDestinationEcho);

      // Test hold
      await $.holdCall();
      await $.pumpAndSettle();

      // Verify hold state (play arrow should appear)
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      // Test unhold
      await $.unholdCall();
      await $.pumpAndSettle();

      // Verify unhold state (pause icon should appear)
      expect(find.byIcon(Icons.pause), findsOneWidget);

      // Cleanup
      await $.endCall();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  patrolTest(
    'Mute and unmute call',
    timeout: Timeout(TestConfig.testTimeout),
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
      await $.makeCall(TestConfig.testDestinationEcho);

      // Test mute - find mic icon and tap
      final micIcon = find.byIcon(Icons.mic);
      final micOffIcon = find.byIcon(Icons.mic_off);

      if ($.exists(micIcon)) {
        await $.tapIconWithRetry(Icons.mic);
        await $.pumpAndSettle();
        // Should now show mic_off
        expect(find.byIcon(Icons.mic_off), findsOneWidget);

        // Unmute
        await $.tapIconWithRetry(Icons.mic_off);
        await $.pumpAndSettle();
        expect(find.byIcon(Icons.mic), findsOneWidget);
      } else if ($.exists(micOffIcon)) {
        // Already muted, unmute first
        await $.tapIconWithRetry(Icons.mic_off);
        await $.pumpAndSettle();
        expect(find.byIcon(Icons.mic), findsOneWidget);
      }

      // Cleanup
      await $.endCall();
    },
  );

  patrolTest(
    'Toggle speaker',
    timeout: Timeout(TestConfig.testTimeout),
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
      await $.makeCall(TestConfig.testDestinationEcho);

      // Toggle speaker
      await $.toggleSpeaker();
      await $.pumpAndSettle();

      // Toggle back
      await $.toggleSpeaker();
      await $.pumpAndSettle();

      // Cleanup
      await $.endCall();
    },
  );

  patrolTest(
    'Send DTMF tones',
    timeout: Timeout(TestConfig.testTimeout),
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
      await $.makeCall(TestConfig.testDestinationEcho);

      // Send DTMF sequence
      await $.sendDtmf('123');

      // Send more tones
      await $.sendDtmf('456');

      // Cleanup
      await $.endCall();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  patrolTest(
    'Multiple hold/unhold cycles',
    timeout: Timeout(TestConfig.testTimeout),
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
      await $.makeCall(TestConfig.testDestinationEcho);

      // Multiple hold/unhold cycles
      for (var i = 0; i < 3; i++) {
        await $.holdCall();
        await Future.delayed(const Duration(milliseconds: 500));
        await $.unholdCall();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Cleanup
      await $.endCall();
    },
  );
}
