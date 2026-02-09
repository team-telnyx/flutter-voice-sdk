/// Improved Patrol Test - Quick Fixes
///
/// This is an improved version of the existing test that:
/// - Uses polling instead of fixed delays where possible
/// - Adds retry logic for flaky taps
/// - Has longer, more realistic timeouts
/// - Better error messages
///
/// Can be used immediately without example app changes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:telnyx_flutter_webrtc/main.dart';
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/buttons/call_buttons.dart';

// ============================================================================
// CONFIGURATION
// ============================================================================

class Config {
  static const username = String.fromEnvironment('APP_LOGIN_USER', defaultValue: '');
  static const password = String.fromEnvironment('APP_LOGIN_PASSWORD', defaultValue: '');
  static const number = String.fromEnvironment('APP_LOGIN_NUMBER', defaultValue: '');
  static const testDestination = '18004377950';

  // Timeouts - generous to prevent flakiness
  static const appLaunchTimeout = Duration(seconds: 10);
  static const connectionTimeout = Duration(seconds: 30);
  static const callActiveTimeout = Duration(seconds: 20);
  static const uiActionTimeout = Duration(seconds: 5);
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/// Wait for a widget to appear, polling instead of fixed delay
Future<void> waitForWidget(
  PatrolIntegrationTester $,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
  String? description,
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    await $.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      await $.pumpAndSettle();
      return;
    }
  }
  throw TestFailure(
    'Timeout waiting for ${description ?? finder.toString()} after ${timeout.inSeconds}s',
  );
}

/// Wait for text to appear
Future<void> waitForText(
  PatrolIntegrationTester $,
  String text, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  await waitForWidget($, find.text(text), timeout: timeout, description: 'text "$text"');
}

/// Tap with retry logic
Future<void> tapWithRetry(
  PatrolIntegrationTester $,
  Finder finder, {
  int maxAttempts = 3,
  String? description,
}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await $.tester.tap(finder);
      await $.pumpAndSettle();
      return;
    } catch (e) {
      if (attempt == maxAttempts) {
        throw TestFailure(
          'Failed to tap ${description ?? finder.toString()} after $maxAttempts attempts: $e',
        );
      }
      await Future.delayed(const Duration(milliseconds: 500));
      await $.pump();
    }
  }
}

/// Wait for call to be established (look for call UI elements)
Future<void> waitForCallActive(PatrolIntegrationTester $) async {
  // Wait for call controls to appear (indicates active call)
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < Config.callActiveTimeout) {
    await $.pump(const Duration(milliseconds: 300));

    // Check for call control icons that indicate active call
    final pauseButton = find.byIcon(Icons.pause);
    final micButton = find.byIcon(Icons.mic);
    final dialpadButton = find.byIcon(Icons.dialpad);

    // If we see call controls, call is likely active
    if (pauseButton.evaluate().isNotEmpty ||
        micButton.evaluate().isNotEmpty ||
        dialpadButton.evaluate().isNotEmpty) {
      await $.pumpAndSettle();
      return;
    }
  }
  throw TestFailure('Call did not become active within ${Config.callActiveTimeout.inSeconds}s');
}

/// Custom error handler
void ignoreOverflowErrors(FlutterErrorDetails details, {bool forceReport = false}) {
  final exception = details.exception;
  if (exception is FlutterError) {
    final isOverflow = exception.diagnostics.any(
      (e) => e.value.toString().contains('A RenderFlex overflowed by'),
    );
    final isAssetError = exception.diagnostics.any(
      (e) => e.value.toString().contains('Unable to load asset'),
    );
    if (isOverflow || isAssetError) {
      debugPrint('Ignored: ${exception.toString()}');
      return;
    }
  }
  FlutterError.dumpErrorToConsole(details, forceReport: forceReport);
}

// ============================================================================
// TESTS
// ============================================================================

void main() {
  patrolTest(
    'Full call flow test (improved)',
    framePolicy: LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
    ($) async {
      // Setup error handling
      final originalOnError = FlutterError.onError;
      FlutterError.onError = ignoreOverflowErrors;
      addTearDown(() => FlutterError.onError = originalOnError);

      // ========================================
      // 1. LAUNCH APP
      // ========================================
      await $.pumpWidgetAndSettle(const MyApp());

      // Wait for app to be ready (look for UI elements instead of fixed delay)
      await waitForText($, 'Switch Profile', timeout: Config.appLaunchTimeout);

      // Grant permissions
      try {
        await $.native.grantPermissionWhenInUse();
      } catch (_) {}

      // ========================================
      // 2. LOGIN WITH SIP CREDENTIALS
      // ========================================
      await tapWithRetry($, find.text('Switch Profile'), description: 'Switch Profile');
      await tapWithRetry($, find.text('Add new profile'), description: 'Add new profile');

      // Fill credentials
      await $.tester.enterText(find.byType(TextFormField).at(0), Config.username);
      await $.tester.enterText(find.byType(TextFormField).at(1), Config.password);
      await $.tester.enterText(find.byType(TextFormField).at(2), 'Integration Test User');
      await $.tester.enterText(find.byType(TextFormField).at(3), Config.number);
      await $.pumpAndSettle();

      // Save profile
      await tapWithRetry($, find.text('Save'), description: 'Save');

      // Select profile
      await tapWithRetry($, find.text('Integration Test User'), description: 'Select profile');

      // Confirm if present
      final confirmButton = find.text('Confirm');
      if (confirmButton.evaluate().isNotEmpty) {
        await tapWithRetry($, confirmButton, description: 'Confirm');
      }

      // Connect if present
      final connectButton = find.text('Connect');
      if (connectButton.evaluate().isNotEmpty) {
        await tapWithRetry($, connectButton, description: 'Connect');
      }

      // ========================================
      // 3. WAIT FOR CONNECTION
      // ========================================
      // Poll for connection indicators instead of fixed delay
      final stopwatch = Stopwatch()..start();
      bool connected = false;
      while (stopwatch.elapsed < Config.connectionTimeout && !connected) {
        await $.pump(const Duration(milliseconds: 500));

        // Look for signs of connection:
        // - "Disconnect" button appears (means we're connected)
        // - Number input field is enabled
        // - Call button is visible
        final disconnectBtn = find.text('Disconnect');
        final callBtn = find.byType(CallButton);

        if (disconnectBtn.evaluate().isNotEmpty || callBtn.evaluate().isNotEmpty) {
          connected = true;
        }
      }

      if (!connected) {
        throw TestFailure('Failed to connect within ${Config.connectionTimeout.inSeconds}s');
      }

      await $.pumpAndSettle();

      // ========================================
      // 4. MAKE OUTBOUND CALL
      // ========================================
      await $.tester.enterText(find.byType(TextFormField).at(0), Config.testDestination);
      await $.pumpAndSettle();

      await tapWithRetry($, find.byType(CallButton), description: 'Call button');

      try {
        await $.native.grantPermissionWhenInUse();
      } catch (_) {}

      // Wait for call to become active
      await waitForCallActive($);

      // ========================================
      // 5. TEST HOLD/UNHOLD
      // ========================================
      await tapWithRetry($, find.byIcon(Icons.pause), description: 'Hold (pause)');
      await Future.delayed(const Duration(milliseconds: 500));
      await tapWithRetry($, find.byIcon(Icons.play_arrow), description: 'Unhold (play)');

      // ========================================
      // 6. TEST MUTE/UNMUTE
      // ========================================
      final micIcon = find.byIcon(Icons.mic);
      if (micIcon.evaluate().isNotEmpty) {
        await tapWithRetry($, micIcon, description: 'Mute');
        await Future.delayed(const Duration(milliseconds: 300));
        await tapWithRetry($, find.byIcon(Icons.mic_off), description: 'Unmute');
      }

      // ========================================
      // 7. TEST DTMF
      // ========================================
      await tapWithRetry($, find.byIcon(Icons.dialpad), description: 'Open keypad');
      await $.pumpAndSettle();

      for (final digit in ['1', '2', '3']) {
        await tapWithRetry($, find.text(digit), description: 'DTMF $digit');
        await Future.delayed(const Duration(milliseconds: 150));
      }

      await tapWithRetry($, find.byIcon(Icons.close), description: 'Close keypad');

      // ========================================
      // 8. END CALL
      // ========================================
      await tapWithRetry($, find.byType(DeclineButton), description: 'End call');
      await $.pumpAndSettle();

      // ========================================
      // 9. VERIFY BACK TO HOME
      // ========================================
      await waitForWidget(
        $,
        find.byType(HomeScreen),
        timeout: Config.uiActionTimeout,
        description: 'HomeScreen',
      );

      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );
}
