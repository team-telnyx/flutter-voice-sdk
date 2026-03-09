import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/buttons/call_buttons.dart';
import 'test_config.dart';
import 'ui_helpers.dart';
import 'wait_helpers.dart';

/// Extension for call-specific test helpers
extension CallHelpers on PatrolIntegrationTester {
  /// Complete login flow with SIP credentials
  Future<void> loginWithSipCredentials({
    String? username,
    String? password,
    String? callerNumber,
    String profileName = 'Test Profile',
  }) async {
    final user = username ?? TestConfig.sipUsername;
    final pass = password ?? TestConfig.sipPassword;
    final number = callerNumber ?? TestConfig.sipCallerNumber;

    // Open profile sheet
    await tapTextWithRetry('Switch Profile');

    // Add new profile
    await tapTextWithRetry('Add new profile');

    // Fill credentials
    await enterTextWithRetry(0, user);
    await enterTextWithRetry(1, pass);
    await enterTextWithRetry(2, profileName);
    await enterTextWithRetry(3, number);

    // Dismiss keyboard before tapping Save (keyboard may block button)
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpAndSettle();
    
    // Also try tapping outside to ensure keyboard is gone
    await tester.tapAt(const Offset(10, 10));
    await pumpAndSettle();

    // Save
    await tapTextWithRetry('Save');

    // Select the profile
    await tapTextWithRetry(profileName);

    // Confirm if button exists
    await tapTextIfExists('Confirm');

    // Connect if button exists
    await tapTextIfExists('Connect');

    // Wait for connection state (clientReady = connected + registered)
    await waitForConnected();

    // Wait for bottom sheet to fully dismiss and destination field to be visible
    // Simple poll instead of extension call to avoid cross-extension issues
    final destinationField = find.byKey(const Key('destination_field'));
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < TestConfig.uiSettleTimeout) {
      await pump(const Duration(milliseconds: 100));
      if (destinationField.evaluate().isNotEmpty) break;
    }
  }

  /// Make an outbound call to a destination
  Future<void> makeCall(String destination) async {
    // Enter destination number - use the specific key to avoid grabbing wrong field
    final numberField = find.byKey(const Key('destination_field'));
    await tester.enterText(numberField, destination);
    await pumpAndSettle();

    // Tap call button
    await tapWithRetry(find.byType(CallButton), description: 'CallButton');

    // Grant permissions if needed
    await grantPermissionsIfNeeded();

    // Wait for call to become active (state-based!)
    await waitForCallActive();
  }

  /// End the current call
  Future<void> endCall() async {
    await tapWithRetry(find.byType(DeclineButton), description: 'DeclineButton');
    await waitForCallEnded();
  }

  /// Toggle hold state
  Future<void> toggleHold() async {
    // Try pause icon first (call is active), then play (call is held)
    final pauseIcon = find.byIcon(Icons.pause);
    final playIcon = find.byIcon(Icons.play_arrow);

    if (exists(pauseIcon)) {
      await tapIconWithRetry(Icons.pause);
    } else if (exists(playIcon)) {
      await tapIconWithRetry(Icons.play_arrow);
    } else {
      throw TestFailure('Neither pause nor play icon found for hold toggle');
    }
  }

  /// Put call on hold
  Future<void> holdCall() async {
    await tapIconWithRetry(Icons.pause);
  }

  /// Resume held call
  Future<void> unholdCall() async {
    await tapIconWithRetry(Icons.play_arrow);
  }

  /// Toggle mute state
  Future<void> toggleMute() async {
    final micIcon = find.byIcon(Icons.mic);
    final micOffIcon = find.byIcon(Icons.mic_off);

    if (exists(micIcon)) {
      await tapIconWithRetry(Icons.mic);
    } else if (exists(micOffIcon)) {
      await tapIconWithRetry(Icons.mic_off);
    } else {
      throw TestFailure('Neither mic nor mic_off icon found for mute toggle');
    }
  }

  /// Toggle speaker
  Future<void> toggleSpeaker() async {
    final speakerIcon = find.byIcon(Icons.volume_up);
    final speakerOffIcon = find.byIcon(Icons.volume_off);

    if (exists(speakerIcon)) {
      await tapIconWithRetry(Icons.volume_up);
    } else if (exists(speakerOffIcon)) {
      await tapIconWithRetry(Icons.volume_off);
    } else {
      // Try alternative icons
      await tapIfExists(find.byIcon(Icons.speaker_phone)) ||
          await tapIfExists(find.byIcon(Icons.phone_in_talk));
    }
  }

  /// Open DTMF keypad
  Future<void> openKeypad() async {
    await tapIconWithRetry(Icons.dialpad);
  }

  /// Close DTMF keypad
  Future<void> closeKeypad() async {
    await tapIconWithRetry(Icons.close);
  }

  /// Send DTMF tones
  Future<void> sendDtmf(String digits) async {
    await openKeypad();

    for (final digit in digits.split('')) {
      await tapTextWithRetry(digit);
      await Future.delayed(const Duration(milliseconds: 200)); // Brief gap between tones
    }

    await closeKeypad();
  }
}
