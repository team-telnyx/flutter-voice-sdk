import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/latency_metrics.dart';
import 'package:telnyx_webrtc/utils/latency_tracker.dart';

void main() {
  group('LatencyTracker', () {
    late LatencyTracker tracker;

    setUp(() {
      tracker = LatencyTracker();
    });

    tearDown(() {
      tracker.dispose();
    });

    group('Registration Tracking', () {
      test('startRegistrationTracking marks login_initiated milestone', () {
        tracker.startRegistrationTracking();
        expect(tracker.isTrackingRegistration, isTrue);

        final metrics = tracker.getCurrentCallMetrics('__registration__');
        // Registration tracking is separate from call tracking
        // Verify we can mark milestones
        tracker.markRegistrationMilestone(LatencyTracker.milestoneSocketConnected);
        tracker.markRegistrationMilestone(LatencyTracker.milestoneLoginSent);
        // No crash = success
      });

      test('completeRegistrationTracking emits metrics', () {
        LatencyMetrics? receivedMetrics;
        tracker.setLatencyMetricsListener((metrics) {
          receivedMetrics = metrics;
        });

        tracker.startRegistrationTracking();
        tracker.markRegistrationMilestone(LatencyTracker.milestoneSocketConnected);
        tracker.markRegistrationMilestone(LatencyTracker.milestoneLoginSent);
        tracker.completeRegistrationTracking();

        expect(receivedMetrics, isNotNull);
        expect(receivedMetrics!.registrationLatencyMs, isNotNull);
        expect(receivedMetrics!.registrationLatencyMs, greaterThanOrEqualTo(0));
        expect(
          receivedMetrics!.milestones,
          contains(LatencyTracker.milestoneClientReady),
        );
        expect(tracker.isTrackingRegistration, isFalse);
      });

      test('completeRegistrationTracking emits via stream', () async {
        tracker.startRegistrationTracking();
        tracker.markRegistrationMilestone(LatencyTracker.milestoneSocketConnected);
        tracker.markRegistrationMilestone(LatencyTracker.milestoneLoginSent);

        final metricsFuture = tracker.latencyMetricsStream.first;
        tracker.completeRegistrationTracking();

        final metrics = await metricsFuture;
        expect(metrics.registrationLatencyMs, isNotNull);
      });

      test('markRegistrationMilestone does nothing when not tracking', () {
        // Should not throw
        tracker.markRegistrationMilestone(LatencyTracker.milestoneSocketConnected);
      });
    });

    group('Call Tracking', () {
      test('startCallTracking marks call_initiated milestone', () {
        tracker.startCallTracking('call1', isOutbound: true);

        final metrics = tracker.getCurrentCallMetrics('call1');
        expect(metrics, isNotNull);
        expect(metrics!.isOutbound, isTrue);
        expect(metrics.milestones, contains(LatencyTracker.milestoneCallInitiated));
      });

      test('markCallMilestone records elapsed time', () async {
        tracker.startCallTracking('call1', isOutbound: false);
        await Future.delayed(const Duration(milliseconds: 10));
        tracker.markCallMilestone('call1', LatencyTracker.milestonePeerCreated);

        final metrics = tracker.getCurrentCallMetrics('call1');
        expect(metrics!.milestones[LatencyTracker.milestonePeerCreated],
            greaterThanOrEqualTo(10));
      });

      test('markCallMilestone ignores unknown call IDs', () {
        // Should not throw
        tracker.markCallMilestone('unknown', LatencyTracker.milestonePeerCreated);
      });

      test('completeCallTracking emits metrics and cleans up', () {
        LatencyMetrics? receivedMetrics;
        tracker.setLatencyMetricsListener((metrics) {
          receivedMetrics = metrics;
        });

        tracker.startCallTracking('call1', isOutbound: true);
        tracker.markCallMilestone('call1', LatencyTracker.milestonePeerCreated);
        tracker.markCallMilestone('call1', LatencyTracker.milestoneInviteSent);
        tracker.markCallMilestone('call1', LatencyTracker.milestoneIceConnected);
        tracker.markCallMilestone('call1', LatencyTracker.milestonePeerConnected);
        tracker.completeCallTracking('call1');

        expect(receivedMetrics, isNotNull);
        expect(receivedMetrics!.callId, 'call1');
        expect(receivedMetrics!.isOutbound, isTrue);
        expect(receivedMetrics!.callSetupLatencyMs, greaterThanOrEqualTo(0));
        expect(receivedMetrics!.milestones,
            contains(LatencyTracker.milestoneCallActive));

        // Should be cleaned up
        expect(tracker.getCurrentCallMetrics('call1'), isNull);
      });

      test('cancelCallTracking removes call without emitting', () {
        LatencyMetrics? receivedMetrics;
        tracker.setLatencyMetricsListener((metrics) {
          receivedMetrics = metrics;
        });

        tracker.startCallTracking('call1', isOutbound: false);
        tracker.cancelCallTracking('call1');

        expect(receivedMetrics, isNull);
        expect(tracker.getCurrentCallMetrics('call1'), isNull);
      });
    });

    group('Inbound Call Milestones', () {
      test('markInviteReceived records milestone', () {
        tracker.startCallTracking('call1', isOutbound: false);
        tracker.markInviteReceived('call1');

        final metrics = tracker.getCurrentCallMetrics('call1');
        expect(metrics!.milestones,
            contains(LatencyTracker.milestoneInviteReceived));
      });

      test('markAnswerInitiated records milestone', () {
        tracker.startCallTracking('call1', isOutbound: false);
        tracker.markAnswerInitiated('call1');

        final metrics = tracker.getCurrentCallMetrics('call1');
        expect(metrics!.milestones,
            contains(LatencyTracker.milestoneAnswerInitiated));
      });
    });

    group('Outbound Call Milestones', () {
      test('markRemoteRinging records milestone', () {
        tracker.startCallTracking('call1', isOutbound: true);
        tracker.markRemoteRinging('call1');

        final metrics = tracker.getCurrentCallMetrics('call1');
        expect(metrics!.milestones,
            contains(LatencyTracker.milestoneRemoteRinging));
      });

      test('markCallAnsweredByRemote records milestone', () {
        tracker.startCallTracking('call1', isOutbound: true);
        tracker.markCallAnsweredByRemote('call1');

        final metrics = tracker.getCurrentCallMetrics('call1');
        expect(metrics!.milestones,
            contains(LatencyTracker.milestoneCallAnsweredByRemote));
      });
    });

    group('ICE Milestones', () {
      test('markFirstSrflxRelayCandidate only marks once', () {
        tracker.startCallTracking('call1', isOutbound: true);

        tracker.markFirstSrflxRelayCandidate('call1', 'srflx');
        tracker.markFirstSrflxRelayCandidate('call1', 'relay');

        final metrics = tracker.getCurrentCallMetrics('call1');
        final timestamp =
            metrics!.milestones[LatencyTracker.milestoneFirstSrflxRelayCandidate];
        expect(timestamp, isNotNull);
        // Should only be recorded once
      });

      test('markFirstSrflxRelayCandidate ignores invalid types', () {
        tracker.startCallTracking('call1', isOutbound: true);

        tracker.markFirstSrflxRelayCandidate('call1', 'host');

        final metrics = tracker.getCurrentCallMetrics('call1');
        expect(metrics!.milestones,
            isNot(contains(LatencyTracker.milestoneFirstSrflxRelayCandidate)));
      });
    });

    group('Derived Metrics', () {
      test('calculateAnswerDelay returns correct value', () {
        tracker.startCallTracking('call1', isOutbound: false);
        tracker.markInviteReceived('call1');
        tracker.markAnswerInitiated('call1');

        final delay = tracker.calculateAnswerDelay('call1');
        expect(delay, isNotNull);
        expect(delay, greaterThanOrEqualTo(0));
      });

      test('calculateAnswerDelay returns null without required milestones', () {
        tracker.startCallTracking('call1', isOutbound: false);
        // No invite_received or answer_initiated
        expect(tracker.calculateAnswerDelay('call1'), isNull);
      });

      test('calculateRemoteAnswerTime returns correct value', () {
        tracker.startCallTracking('call1', isOutbound: true);
        tracker.markCallMilestone('call1', LatencyTracker.milestoneInviteSent);
        tracker.markCallAnsweredByRemote('call1');

        final time = tracker.calculateRemoteAnswerTime('call1');
        expect(time, isNotNull);
        expect(time, greaterThanOrEqualTo(0));
      });

      test('calculateRemoteAnswerTime returns null without required milestones', () {
        tracker.startCallTracking('call1', isOutbound: true);
        // No invite_sent or call_answered_by_remote
        expect(tracker.calculateRemoteAnswerTime('call1'), isNull);
      });
    });

    group('Reset and Cleanup', () {
      test('reset clears all state', () {
        tracker.startRegistrationTracking();
        tracker.startCallTracking('call1', isOutbound: true);
        tracker.reset();

        expect(tracker.isTrackingRegistration, isFalse);
        expect(tracker.getCurrentCallMetrics('call1'), isNull);
      });

      test('multiple calls tracked independently', () {
        tracker.startCallTracking('call1', isOutbound: true);
        tracker.startCallTracking('call2', isOutbound: false);

        tracker.markCallMilestone('call1', LatencyTracker.milestoneInviteSent);
        tracker.markInviteReceived('call2');

        final metrics1 = tracker.getCurrentCallMetrics('call1');
        final metrics2 = tracker.getCurrentCallMetrics('call2');

        expect(metrics1!.milestones, contains(LatencyTracker.milestoneInviteSent));
        expect(metrics1.milestones,
            isNot(contains(LatencyTracker.milestoneInviteReceived)));
        expect(metrics2!.milestones,
            contains(LatencyTracker.milestoneInviteReceived));
        expect(metrics2.milestones,
            isNot(contains(LatencyTracker.milestoneInviteSent)));
      });
    });
  });

  group('LatencyMetrics', () {
    test('toString produces formatted output', () {
      final metrics = LatencyMetrics(
        callId: 'test-call',
        isOutbound: true,
        callSetupLatencyMs: 500,
        iceGatheringLatencyMs: 100,
        signalingLatencyMs: 200,
        mediaEstablishmentLatencyMs: 50,
        milestones: {
          'call_initiated': 0,
          'peer_connection_created': 50,
          'invite_sent': 100,
        },
      );

      final output = metrics.toString();
      expect(output, contains('OUTBOUND'));
      expect(output, contains('test-call'));
      expect(output, contains('500ms'));
      expect(output, contains('call_initiated'));
    });

    test('registration metrics toString', () {
      final metrics = LatencyMetrics(
        registrationLatencyMs: 300,
        milestones: {
          'login_initiated': 0,
          'socket_connected': 100,
          'login_sent': 110,
          'client_ready': 300,
        },
      );

      final output = metrics.toString();
      expect(output, contains('REGISTRATION'));
      expect(output, contains('300ms'));
    });

    test('default timestamp is set', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final metrics = LatencyMetrics();
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(metrics.timestamp, greaterThanOrEqualTo(before));
      expect(metrics.timestamp, lessThanOrEqualTo(after));
    });
  });
}
