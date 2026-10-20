import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/call_recovery_coordinator.dart';

class _SpyListener implements RecoveryCoordinatorListener {
  _SpyListener(this.callId);

  @override
  final String callId;

  int restartTimeoutCount = 0;
  int verifyingMediaTimeoutCount = 0;
  int disconnectedDebounceCount = 0;
  final List<RecoveryDismissReason> dismisses = <RecoveryDismissReason>[];

  @override
  void onRestartTimeout(int generation) {
    restartTimeoutCount += 1;
  }

  @override
  void onVerifyingMediaTimeout(int generation) {
    verifyingMediaTimeoutCount += 1;
  }

  @override
  void onDisconnectedDebounceExpired(int generation) {
    disconnectedDebounceCount += 1;
  }

  @override
  void onRecoveryDismissed(int generation, RecoveryDismissReason reason) {
    dismisses.add(reason);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CallRecoveryCoordinator (VSDK-680)', () {
    test('startRestart bumps generation and transitions to iceRestarting', () {
      final clock = FakeClock();
      final listener = _SpyListener('call-1');
      final coordinator = CallRecoveryCoordinator(
        callId: 'call-1',
        listener: listener,
        clock: clock,
      );

      expect(coordinator.phase, RecoveryPhase.idle);
      expect(coordinator.generation, 0);

      final gen = coordinator.startRestart();
      expect(gen, 1);
      expect(coordinator.generation, 1);
      expect(coordinator.phase, RecoveryPhase.iceRestarting);
    });

    test('startRestart twice bumps generation and supersedes prior timers', () {
      final clock = FakeClock();
      final listener = _SpyListener('call-1');
      final coordinator = CallRecoveryCoordinator(
        callId: 'call-1',
        listener: listener,
        clock: clock,
      );

      final gen1 = coordinator.startRestart();
      final gen2 = coordinator.startRestart();
      expect(gen2, gen1 + 1);
      expect(coordinator.generation, gen2);

      // Advance past the first (15s) restart timeout — gen1 is stale now.
      clock.elapse(const Duration(seconds: 16));
      expect(
        listener.restartTimeoutCount,
        1,
        reason: 'only the latest generation fires its timer',
      );

      // Advance another 15s — no extra fires expected: gen1 was superseded
      // (cancelled) and gen2 already fired during the first elapse. The
      // invariant is "exactly one fire per started generation" — gen2's
      // timer fires once, gen1's was superseded (its callback saw a stale
      // generation and returned without invoking the listener).
      clock.elapse(const Duration(seconds: 15));
      expect(listener.restartTimeoutCount, 1);
    });

    test('15-second restart timeout fires onRestartTimeout', () {
      final clock = FakeClock();
      final listener = _SpyListener('call-1');
      final coordinator = CallRecoveryCoordinator(
        callId: 'call-1',
        listener: listener,
        clock: clock,
      );
      coordinator.startRestart();

      clock.elapse(const Duration(seconds: 14));
      expect(listener.restartTimeoutCount, 0);

      clock.elapse(const Duration(seconds: 2));
      expect(listener.restartTimeoutCount, 1);
    });

    test(
        'connected ICE during restart cancels the 15-second timeout and '
        'transitions to idle', () {
      final clock = FakeClock();
      final listener = _SpyListener('call-1');
      final coordinator = CallRecoveryCoordinator(
        callId: 'call-1',
        listener: listener,
        clock: clock,
      );
      coordinator.startRestart();
      clock.elapse(const Duration(seconds: 5));

      coordinator.onIceStateChanged(
        generation: coordinator.generation,
        state: ConnectionIceState.connected,
      );
      expect(coordinator.phase, RecoveryPhase.idle);

      // 15-second timer is now cancelled — advance past the original deadline.
      clock.elapse(const Duration(seconds: 20));
      expect(
        listener.restartTimeoutCount,
        0,
        reason: 'connected should cancel the restart timer',
      );
    });

    test('verifyingMedia confirms on inbound RTP growth', () {
      final clock = FakeClock();
      final listener = _SpyListener('call-1');
      final coordinator = CallRecoveryCoordinator(
        callId: 'call-1',
        listener: listener,
        clock: clock,
      );
      coordinator.startRestart();
      coordinator.onAnswerApplied(
        generation: coordinator.generation,
        baselineInboundBytes: 100,
      );
      expect(coordinator.phase, RecoveryPhase.verifyingMedia);

      // Same baseline → not growth.
      final noGrowth = coordinator.noteInboundRtpBytes(
        generation: coordinator.generation,
        inboundBytes: 100,
      );
      expect(noGrowth, isFalse);
      expect(coordinator.phase, RecoveryPhase.verifyingMedia);

      // Strictly greater → growth → idle.
      final grown = coordinator.noteInboundRtpBytes(
        generation: coordinator.generation,
        inboundBytes: 250,
      );
      expect(grown, isTrue);
      expect(coordinator.phase, RecoveryPhase.idle);

      // Timer should be cancelled — verify no verifyingMediaTimeout fires.
      clock.elapse(const Duration(seconds: 10));
      expect(listener.verifyingMediaTimeoutCount, 0);
    });

    test('verifyingMedia timeout fires when no inbound RTP growth', () {
      final clock = FakeClock();
      final listener = _SpyListener('call-1');
      final coordinator = CallRecoveryCoordinator(
        callId: 'call-1',
        listener: listener,
        clock: clock,
      );
      coordinator.startRestart();
      coordinator.onAnswerApplied(
        generation: coordinator.generation,
        baselineInboundBytes: 100,
      );

      clock.elapse(const Duration(seconds: 5));
      expect(listener.verifyingMediaTimeoutCount, 1);
      expect(
        listener.dismisses,
        isNot(contains(RecoveryDismissReason.superseded)),
      );
    });

    test('disconnected ICE starts a 3-second debounce; connected cancels it',
        () {
      final clock = FakeClock();
      final listener = _SpyListener('call-1');
      final coordinator = CallRecoveryCoordinator(
        callId: 'call-1',
        listener: listener,
        clock: clock,
      );

      coordinator.onIceStateChanged(
        generation: coordinator.generation,
        state: ConnectionIceState.disconnected,
      );
      expect(coordinator.phase, RecoveryPhase.probing);

      clock.elapse(const Duration(seconds: 2));
      // 2 seconds in — debounce still pending.
      expect(listener.disconnectedDebounceCount, 0);

      coordinator.onIceStateChanged(
        generation: coordinator.generation,
        state: ConnectionIceState.connected,
      );
      expect(coordinator.phase, RecoveryPhase.idle);

      // The 3-second debounce is cancelled — should never fire.
      clock.elapse(const Duration(seconds: 5));
      expect(
        listener.disconnectedDebounceCount,
        0,
        reason: 'connected should cancel the debounce timer',
      );
      expect(
        listener.dismisses,
        contains(RecoveryDismissReason.recovered),
      );
    });

    test('disconnected debounce expires → onDisconnectedDebounceExpired', () {
      final clock = FakeClock();
      final listener = _SpyListener('call-1');
      final coordinator = CallRecoveryCoordinator(
        callId: 'call-1',
        listener: listener,
        clock: clock,
      );

      coordinator.onIceStateChanged(
        generation: coordinator.generation,
        state: ConnectionIceState.disconnected,
      );
      clock.elapse(const Duration(seconds: 3));
      expect(listener.disconnectedDebounceCount, 1);
    });

    test('stale-generation callbacks are ignored', () {
      final clock = FakeClock();
      final listener = _SpyListener('call-1');
      final coordinator = CallRecoveryCoordinator(
        callId: 'call-1',
        listener: listener,
        clock: clock,
      );
      final gen1 = coordinator.startRestart();
      // Simulate a second restart that supersedes the first.
      coordinator.startRestart();

      // Stale call from gen1 should be a no-op.
      final applied = coordinator.onAnswerApplied(
        generation: gen1,
        baselineInboundBytes: 0,
      );
      expect(applied, isFalse);
      expect(coordinator.phase, RecoveryPhase.iceRestarting);

      final staleRtp = coordinator.noteInboundRtpBytes(
        generation: gen1,
        inboundBytes: 9999,
      );
      expect(staleRtp, isFalse);

      final staleIce = coordinator.onIceStateChanged(
        generation: gen1,
        state: ConnectionIceState.disconnected,
      );
      expect(staleIce, RecoveryPhase.iceRestarting);

      final staleFallback = coordinator.requestFallbackReattach(
        generation: gen1,
        reason: FallbackReattachReason.restartTimeout,
      );
      expect(staleFallback, isFalse);

      expect(
        listener.dismisses.where((r) => r == RecoveryDismissReason.superseded),
        isNotEmpty,
        reason: 'every stale-generation call should report superseded',
      );
    });

    test('one fallback reattach per generation', () {
      final clock = FakeClock();
      final listener = _SpyListener('call-1');
      final coordinator = CallRecoveryCoordinator(
        callId: 'call-1',
        listener: listener,
        clock: clock,
      );
      coordinator.startRestart();

      final first = coordinator.requestFallbackReattach(
        generation: coordinator.generation,
        reason: FallbackReattachReason.restartTimeout,
      );
      expect(first, isTrue);

      final second = coordinator.requestFallbackReattach(
        generation: coordinator.generation,
        reason: FallbackReattachReason.verifyingMediaTimeout,
      );
      expect(second, isFalse, reason: 'one fallback per generation');
    });

    test('dispose cancels all timers and ignores callbacks', () {
      final clock = FakeClock();
      final listener = _SpyListener('call-1');
      final coordinator = CallRecoveryCoordinator(
        callId: 'call-1',
        listener: listener,
        clock: clock,
      );
      coordinator.startRestart();
      coordinator.dispose();
      expect(coordinator.isDisposed, isTrue);

      clock.elapse(const Duration(seconds: 30));
      expect(listener.restartTimeoutCount, 0);
      expect(listener.verifyingMediaTimeoutCount, 0);
      expect(listener.disconnectedDebounceCount, 0);
    });

    test('disconnected ICE during restart does not start a second debounce',
        () {
      final clock = FakeClock();
      final listener = _SpyListener('call-1');
      final coordinator = CallRecoveryCoordinator(
        callId: 'call-1',
        listener: listener,
        clock: clock,
      );
      coordinator.startRestart();
      expect(coordinator.phase, RecoveryPhase.iceRestarting);

      // Disconnected while iceRestarting — should NOT downgrade to probing.
      final nextPhase = coordinator.onIceStateChanged(
        generation: coordinator.generation,
        state: ConnectionIceState.disconnected,
      );
      expect(nextPhase, RecoveryPhase.iceRestarting);
    });
  });
}
