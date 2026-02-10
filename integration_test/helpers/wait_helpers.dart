import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import 'test_config.dart';

/// Extension on PatrolIntegrationTester for state-based waiting
extension WaitHelpers on PatrolIntegrationTester {
  /// Wait until a finder finds at least one widget, with timeout.
  /// Much better than arbitrary Future.delayed!
  Future<void> waitUntilVisible(
    Finder finder, {
    Duration? timeout,
    String? description,
  }) async {
    final effectiveTimeout = timeout ?? TestConfig.uiSettleTimeout;
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < effectiveTimeout) {
      await pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }

    throw TestFailure(
      'Timeout waiting for ${description ?? finder.toString()} '
      'after ${effectiveTimeout.inSeconds}s',
    );
  }

  /// Wait until text appears on screen
  Future<void> waitForText(
    String text, {
    Duration? timeout,
  }) async {
    await waitUntilVisible(
      find.text(text),
      timeout: timeout,
      description: 'text "$text"',
    );
  }

  /// Wait until a widget with specific Key appears
  Future<void> waitForKey(
    String key, {
    Duration? timeout,
  }) async {
    await waitUntilVisible(
      find.byKey(Key(key)),
      timeout: timeout,
      description: 'key "$key"',
    );
  }

  /// Wait until widget with Key contains expected text
  Future<void> waitForKeyWithText(
    String key,
    String expectedText, {
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? TestConfig.connectionTimeout;
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < effectiveTimeout) {
      await pump(const Duration(milliseconds: 200));

      final finder = find.byKey(Key(key));
      if (finder.evaluate().isNotEmpty) {
        final widget = finder.evaluate().first.widget;
        if (widget is Text && widget.data?.contains(expectedText) == true) {
          return;
        }
      }
    }

    throw TestFailure(
      'Timeout waiting for key "$key" to contain "$expectedText" '
      'after ${effectiveTimeout.inSeconds}s',
    );
  }

  /// Wait for SDK connection status (requires status widget with key)
  /// Note: 'clientReady' means connected AND registered (ready to make calls)
  Future<void> waitForConnected({Duration? timeout}) async {
    await waitForKeyWithText(
      'connection_status',
      'clientReady',
      timeout: timeout ?? TestConfig.connectionTimeout,
    );
  }

  /// Wait for call to become active (requires call status widget with key)
  Future<void> waitForCallActive({Duration? timeout}) async {
    await waitForKeyWithText(
      'call_status',
      'active',
      timeout: timeout ?? TestConfig.callEstablishTimeout,
    );
  }

  /// Wait for call to end
  Future<void> waitForCallEnded({Duration? timeout}) async {
    // Either "done" status or back to idle/HomeScreen
    final effectiveTimeout = timeout ?? TestConfig.uiSettleTimeout;
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < effectiveTimeout) {
      await pump(const Duration(milliseconds: 200));

      // Check if we're back at home screen (idle state)
      final homeScreen = find.byType(HomeScreen);
      if (homeScreen.evaluate().isNotEmpty) {
        return;
      }

      // Or check call status widget shows done/idle
      final statusFinder = find.byKey(const Key('call_status'));
      if (statusFinder.evaluate().isNotEmpty) {
        final widget = statusFinder.evaluate().first.widget;
        if (widget is Text) {
          final text = widget.data ?? '';
          if (text.contains('idle') || text.contains('done')) {
            return;
          }
        }
      }
    }

    throw TestFailure(
      'Timeout waiting for call to end after ${effectiveTimeout.inSeconds}s',
    );
  }
}
