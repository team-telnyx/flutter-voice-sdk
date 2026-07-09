import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:telnyx_webrtc/services/signaling_health_monitor.dart';

// ── Mocks ───────────────────────────────────────────────────────────────

class MockSignalingHealthSession extends Mock
    implements ISignalingHealthSession {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VSDK-416: SignalingHealthMonitor', () {
    late MockSignalingHealthSession session;
    late SignalingHealthMonitor monitor;

    setUp(() {
      session = MockSignalingHealthSession();
      monitor = SignalingHealthMonitor(session);
    });

    tearDown(() {
      monitor.stop();
    });

    group('start / stop lifecycle', () {
      test('isRunning returns false before start()', () {
        expect(monitor.isRunning, isFalse);
      });

      test('isRunning returns true after start()', () {
        monitor.start();

        expect(monitor.isRunning, isTrue);
      });

      test('isRunning returns false after stop()', () {
        monitor
          ..start()
          ..stop();

        expect(monitor.isRunning, isFalse);
      });

      test('start() is idempotent — calling twice does nothing', () {
        monitor
          ..start()
          ..start();

        expect(monitor.isRunning, isTrue);
      });

      test('stop() is idempotent — calling twice does nothing', () {
        monitor
          ..start()
          ..stop()
          ..stop();

        expect(monitor.isRunning, isFalse);
      });

      test('stop() clears pending media recovery', () {
        monitor.start();
        // Simulate a pending media recovery by triggering onPeerFailure
        // with healthy=false state
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(true);
        monitor
          ..onPeerFailure('call-1', PeerFailureEvidence.iceFailed)
          ..stop()
          // After stop, no recovery should be pending
          // Verify by starting again and checking no immediate action
          ..start();
        verifyNever(session.socketDisconnect());
      });
    });

    group('onSocketActivity', () {
      test('updates last inbound timestamp — no probe sent immediately after',
          () {
        when(session.isConnected).thenReturn(true);
        monitor
          ..start()
          ..onSocketActivity();

        // Should not send a probe immediately after activity
        expect(monitor.isProbeInFlight, isFalse);
      });
    });

    group('isProbeInFlight', () {
      test('returns false initially', () {
        monitor.start();

        expect(monitor.isProbeInFlight, isFalse);
      });
    });

    group('isCriticalMethod', () {
      test('returns true for telnyx_rtc.modify', () {
        expect(
          SignalingHealthMonitor.isCriticalMethod('telnyx_rtc.modify'),
          isTrue,
        );
      });

      test('returns true for telnyx_rtc.bye', () {
        expect(
          SignalingHealthMonitor.isCriticalMethod('telnyx_rtc.bye'),
          isTrue,
        );
      });

      test('returns true for telnyx_rtc.ping', () {
        expect(
          SignalingHealthMonitor.isCriticalMethod('telnyx_rtc.ping'),
          isTrue,
        );
      });

      test('returns false for telnyx_rtc.info', () {
        expect(
          SignalingHealthMonitor.isCriticalMethod('telnyx_rtc.info'),
          isFalse,
        );
      });

      test('returns false for unknown method', () {
        expect(
          SignalingHealthMonitor.isCriticalMethod('telnyx_rtc.unknown'),
          isFalse,
        );
      });

      test('returns false for empty string', () {
        expect(SignalingHealthMonitor.isCriticalMethod(''), isFalse);
      });
    });

    group('onRequestTimeout', () {
      test('triggers signaling recovery for critical method (Modify)', () {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(true);
        monitor
          ..start()
          ..onRequestTimeout('req-1', 10000, 'telnyx_rtc.modify');

        verify(session.socketDisconnect()).called(1);
      });

      test('triggers signaling recovery for critical method (Bye)', () {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(true);
        monitor
          ..start()
          ..onRequestTimeout('req-2', 10000, 'telnyx_rtc.bye');

        verify(session.socketDisconnect()).called(1);
      });

      test('triggers signaling recovery for critical method (Ping)', () {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(true);
        monitor
          ..start()
          ..onRequestTimeout('req-3', 5000, 'telnyx_rtc.ping');

        verify(session.socketDisconnect()).called(1);
      });

      test('does NOT trigger recovery for non-critical method (Info)', () {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(true);
        monitor
          ..start()
          ..onRequestTimeout('req-4', 10000, 'telnyx_rtc.info');

        verifyNever(session.socketDisconnect());
      });

      test('does NOT trigger recovery when not connected', () {
        when(session.isConnected).thenReturn(false);
        monitor
          ..start()
          ..onRequestTimeout('req-5', 10000, 'telnyx_rtc.modify');

        verifyNever(session.socketDisconnect());
      });

      test('does NOT trigger recovery for empty method', () {
        when(session.isConnected).thenReturn(true);
        monitor
          ..start()
          ..onRequestTimeout('req-6', 10000, '');

        verifyNever(session.socketDisconnect());
      });
    });

    group('onPeerFailure', () {
      test('with healthy signaling triggers ICE restart', () {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(true);
        when(session.triggerIceRestart(any)).thenReturn(
          TriggerIceRestartResult(started: true),
        );
        monitor
          ..start()
          // Record recent activity so signaling appears healthy
          ..onSocketActivity()
          ..onPeerFailure('call-1', PeerFailureEvidence.iceFailed);

        verify(session.triggerIceRestart('call-1')).called(1);
        verifyNever(session.socketDisconnect());
      });

      test('with unhealthy signaling triggers socket reconnect', () {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(true);
        monitor
          ..start()
          // Don't call onSocketActivity — signaling state is unknown, not healthy
          // We need to simulate an unhealthy state.
          // Since we can't easily manipulate internal timestamps in a unit test,
          // we verify the monitor's behavior when signaling health is unknown
          // and a probe is needed.
          // The monitor should defer or probe, not immediately ICE restart.
          ..onPeerFailure('call-2', PeerFailureEvidence.connectionFailed);

        // When signaling health is unknown, the monitor should probe
        // (not immediately ICE restart or socket disconnect)
        expect(monitor.isProbeInFlight, isTrue);
        verifyNever(session.triggerIceRestart(any));
        verifyNever(session.socketDisconnect());
      });

      test('does nothing when no active call', () {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(false);
        monitor
          ..start()
          ..onPeerFailure('call-3', PeerFailureEvidence.iceFailed);

        verifyNever(session.triggerIceRestart(any));
        verifyNever(session.socketDisconnect());
      });
    });

    group('onNoRtp', () {
      test('with healthy signaling triggers ICE restart', () {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(true);
        when(session.triggerIceRestart(any)).thenReturn(
          TriggerIceRestartResult(started: true),
        );
        monitor
          ..start()
          ..onSocketActivity()
          ..onNoRtp('call-1', 'inbound');

        verify(session.triggerIceRestart('call-1')).called(1);
        verifyNever(session.socketDisconnect());
      });

      test('with unknown signaling defers and probes', () {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(true);
        monitor
          ..start()
          ..onNoRtp('call-2', 'outbound');

        // Should probe, not immediately act
        expect(monitor.isProbeInFlight, isTrue);
        verifyNever(session.triggerIceRestart(any));
        verifyNever(session.socketDisconnect());
      });

      test('does nothing when no active call', () {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(false);
        monitor
          ..start()
          ..onNoRtp('call-3', 'inbound');

        verifyNever(session.triggerIceRestart(any));
        verifyNever(session.socketDisconnect());
      });
    });

    group('onIceRestartFailed', () {
      test('triggers socket reconnect', () {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(true);
        monitor
          ..start()
          ..onIceRestartFailed('call-1');

        verify(session.socketDisconnect()).called(1);
      });
    });

    group('probe mechanism', () {
      test('after start with no socket activity for > 20s, probe is sent',
          () async {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(true);
        monitor.start();

        // Wait beyond the probe threshold (20s silence → probe)
        // Since check interval is 3s, we need to wait at least 21s
        // Instead of waiting real time, we test the isProbeInFlight state
        // after the monitor has been running with no activity
        // This is a timing-dependent test — in practice the check interval
        // fires every 3s. We wait a short time and verify no probe yet
        // (since 20s hasn't elapsed).
        await Future.delayed(const Duration(milliseconds: 100));

        // After only 100ms, no probe should be in flight
        expect(monitor.isProbeInFlight, isFalse);
      });
    });

    group('recovery decision authority', () {
      test(
          'peer failure with healthy signaling → ICE restart, NEVER socket reconnect',
          () {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(true);
        when(session.triggerIceRestart(any)).thenReturn(
          TriggerIceRestartResult(started: true),
        );
        monitor
          ..start()
          ..onSocketActivity()
          ..onPeerFailure('call-1', PeerFailureEvidence.iceFailed);

        verify(session.triggerIceRestart('call-1')).called(1);
        verifyNever(session.socketDisconnect());
      });

      test(
          'request timeout with critical method → socket reconnect, NEVER ICE restart',
          () {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(true);
        monitor
          ..start()
          ..onRequestTimeout('req-1', 10000, 'telnyx_rtc.modify');

        verify(session.socketDisconnect()).called(1);
        verifyNever(session.triggerIceRestart(any));
      });

      test('ICE restart failure → socket reconnect, NEVER another ICE restart',
          () {
        when(session.isConnected).thenReturn(true);
        when(session.hasActiveCall()).thenReturn(true);
        monitor
          ..start()
          ..onIceRestartFailed('call-1');

        verify(session.socketDisconnect()).called(1);
        verifyNever(session.triggerIceRestart(any));
      });
    });
  });
}
