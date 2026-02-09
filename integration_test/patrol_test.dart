/// Refactored Patrol Integration Tests
///
/// This is a proposed restructure of the patrol tests with:
/// - State-based waiting instead of arbitrary delays
/// - Retry logic for flaky UI interactions
/// - Isolated test cases for better failure diagnosis
/// - Comprehensive call control coverage
///
/// IMPORTANT: For these tests to work optimally, the example app needs
/// status indicator widgets with Keys:
///
/// ```dart
/// // In home_screen.dart or a debug overlay:
/// Text(
///   'SDK:${connectionStatus.name}',
///   key: const Key('connection_status'),
/// ),
/// Text(
///   'Call:${callState.name}',
///   key: const Key('call_status'),
/// ),
/// ```
///
/// This allows tests to poll for actual SDK state instead of guessing
/// with arbitrary timeouts.

import 'tests/connection_test.dart';
import 'tests/outbound_call_test.dart';
import 'tests/call_controls_test.dart';

void main() {
  // Connection tests
  connectionTests();

  // Outbound call tests
  outboundCallTests();

  // Call controls tests (hold, mute, speaker, DTMF)
  callControlsTests();
}
