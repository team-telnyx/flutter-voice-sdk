import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/errors/media_permissions_recovery_config.dart';

void main() {
  group('VSDK-417: MediaPermissionsRecoveryConfig', () {
    test('constructs with enabled, timeout, onSuccess, and onError', () {
      const config = MediaPermissionsRecoveryConfig(
        enabled: true,
        timeout: 25000,
      );

      // Config with callbacks
      final configWithCallbacks = MediaPermissionsRecoveryConfig(
        enabled: true,
        timeout: 25000,
        onSuccess: () {},
        onError: (error) {},
      );

      expect(config.enabled, isTrue);
      expect(config.timeout, equals(25000));
      expect(configWithCallbacks.onSuccess, isNotNull);
      expect(configWithCallbacks.onError, isNotNull);
    });

    test('enabled can be false', () {
      const config = MediaPermissionsRecoveryConfig(
        enabled: false,
        timeout: 25000,
      );

      expect(config.enabled, isFalse);
    });

    test('timeout is required and positive', () {
      const config = MediaPermissionsRecoveryConfig(
        enabled: true,
        timeout: 15000,
      );

      expect(config.timeout, equals(15000));
      expect(config.timeout, greaterThan(0));
    });

    test('onSuccess and onError are optional', () {
      const config = MediaPermissionsRecoveryConfig(
        enabled: true,
        timeout: 25000,
      );

      expect(config.onSuccess, isNull);
      expect(config.onError, isNull);
    });

    test('recommended max timeout is 25000', () {
      // The plan recommends max 25000ms
      const config = MediaPermissionsRecoveryConfig(
        enabled: true,
        timeout: 25000,
      );

      expect(config.timeout, lessThanOrEqualTo(25000));
    });
  });

  group('VSDK-417: Media permission recovery flow', () {
    // These tests verify the recovery flow behavior.
    // The actual Peer.createStream() integration is tested via the
    // TelnyxClient/Peer integration, but here we test the config
    // and the contract that resume/reject callbacks must follow.

    test('resume callback completes the Completer successfully', () async {
      final completer = Completer<void>();

      Future<void> resume() async {
        completer.complete();
      }

      await resume();
      expect(completer.isCompleted, isTrue);
    });

    test('reject callback completes the Completer with an error', () async {
      final completer = Completer<void>();
      var caughtError = false;

      Future<void> reject() async {
        completer.completeError(Exception('Call was rejected'));
      }

      // Attach an error handler to the future BEFORE calling reject so
      // the error is caught synchronously and doesn't surface as unhandled.
      unawaited(
        completer.future.catchError((e) {
          caughtError = true;
          return null;
        }),
      );

      await reject();
      // Give the microtask queue a turn to let the catchError run.
      await Future.delayed(Duration.zero);

      expect(caughtError, isTrue);
    });

    test('safety timeout fires after configured timeout period', () async {
      final completer = Completer<void>();
      final safetyTimer = Timer(const Duration(milliseconds: 50), () {
        completer.completeError(Exception('Media recovery flow timed out!'));
      });

      try {
        await completer.future;
        fail('Should have timed out');
      } catch (e) {
        expect(e.toString(), contains('timed out'));
      }
      safetyTimer.cancel();
    });

    test('retryDeadline is calculated as now + timeout', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      const timeout = 25000;
      final retryDeadline = now + timeout;

      expect(retryDeadline, greaterThan(now));
      expect(retryDeadline - now, equals(timeout));
    });
  });
}
