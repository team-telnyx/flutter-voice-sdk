import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/src/recovery/call_recovery_monitor.dart';
import 'package:telnyx_webrtc/src/recovery/ice_restart_support.dart';
import 'package:telnyx_webrtc/src/recovery/recovery_signaling.dart';

void main() {
  late List<Map<String, dynamic>> sent;
  late DateTime now;
  late RecoverySignaling signaling;

  setUp(() {
    sent = <Map<String, dynamic>>[];
    now = DateTime(2026, 11, 17, 12);
    signaling = RecoverySignaling(
      send: (message) => sent.add(jsonDecode(message) as Map<String, dynamic>),
      now: () => now,
    );
  });

  tearDown(() => signaling.reset());

  group('signaling freshness', () {
    test('is unknown until frames arrive', () {
      expect(signaling.inboundIdle, isNull);
      expect(signaling.confirmedOutboundIdle, isNull);
    });

    test('tracks inbound frames and confirmed responses separately', () {
      signaling.onInboundFrame();
      now = now.add(const Duration(seconds: 4));
      expect(signaling.inboundIdle, const Duration(seconds: 4));
      expect(signaling.confirmedOutboundIdle, isNull);

      signaling.onResponse('unrelated', <String, dynamic>{'result': {}});
      now = now.add(const Duration(seconds: 1));
      expect(signaling.confirmedOutboundIdle, const Duration(seconds: 1));
    });
  });

  group('correlated probe', () {
    test('sends a telnyx_rtc.ping with a unique id', () async {
      final result = signaling.sendProbe();

      expect(sent.single['method'], 'telnyx_rtc.ping');
      expect(sent.single['jsonrpc'], '2.0');
      final id = sent.single['id'] as String;
      expect(id, isNotEmpty);

      expect(signaling.onResponse(id, <String, dynamic>{'result': {}}), isTrue);
      expect(await result, SignalingProbeResult.ok);
      expect(signaling.pendingCount, 0);
    });

    test('an error response with the same id still proves liveness', () async {
      final result = signaling.sendProbe();
      final id = sent.single['id'] as String;

      signaling.onResponse(id, <String, dynamic>{
        'error': {'code': -32000},
      });

      expect(await result, SignalingProbeResult.ok);
    });

    test('unrelated responses do not resolve the probe', () async {
      var settled = false;
      final result = signaling.sendProbe();
      unawaited(result.then((_) => settled = true));

      expect(
        signaling.onResponse('other', <String, dynamic>{'result': {}}),
        isFalse,
      );
      expect(signaling.onResponse(null, <String, dynamic>{}), isFalse);
      await pumpEventQueue();
      expect(settled, isFalse);

      signaling.onResponse(sent.single['id'] as String, <String, dynamic>{});
      expect(await result, SignalingProbeResult.ok);
    });

    test('a send failure reports an error', () async {
      final failing = RecoverySignaling(
        send: (_) => throw StateError('socket closed'),
      );

      expect(await failing.sendProbe(), SignalingProbeResult.error);
      expect(failing.pendingCount, 0);
    });

    test('an unanswered probe expires as a timeout', () async {
      final short = RecoverySignaling(
        send: (_) {},
        requestExpiry: const Duration(milliseconds: 10),
      );

      expect(await short.sendProbe(), SignalingProbeResult.timeout);
      expect(short.pendingCount, 0);
    });
  });

  group('correlated updateMedia', () {
    test('keeps the existing modify / updateMedia wire format', () {
      signaling
          .sendUpdateMedia(callId: 'call-1', sessid: 'sess-1', sdp: 'offer')
          .ignore();

      final message = sent.single;
      expect(message['method'], 'telnyx_rtc.modify');
      expect(message['jsonrpc'], '2.0');
      final params = message['params'] as Map<String, dynamic>;
      expect(params['action'], 'updateMedia');
      expect(params['sessid'], 'sess-1');
      expect(params['sdp'], 'offer');
      expect((params['dialogParams'] as Map)['callID'], 'call-1');
    });

    test('returns the answer SDP from the matching response', () async {
      final answer = signaling.sendUpdateMedia(
        callId: 'call-1',
        sessid: 'sess-1',
        sdp: 'offer',
      );
      final id = sent.single['id'] as String;

      signaling
        ..onResponse('other', <String, dynamic>{
          'result': {'action': 'updateMedia', 'sdp': 'wrong'},
        })
        ..onResponse(id, <String, dynamic>{
          'result': {'action': 'updateMedia', 'sdp': 'answer'},
        });

      expect(await answer, 'answer');
    });

    test('throws when the request is rejected', () async {
      final answer = signaling.sendUpdateMedia(
        callId: 'call-1',
        sessid: 'sess-1',
        sdp: 'offer',
      );
      signaling.onResponse(sent.single['id'] as String, <String, dynamic>{
        'error': {'code': -32002},
      });

      await expectLater(answer, throwsA(isA<RecoverySignalingException>()));
    });

    test('throws when the answer has no SDP', () async {
      final answer = signaling.sendUpdateMedia(
        callId: 'call-1',
        sessid: 'sess-1',
        sdp: 'offer',
      );
      signaling.onResponse(sent.single['id'] as String, <String, dynamic>{
        'result': {'action': 'updateMedia'},
      });

      await expectLater(answer, throwsA(isA<RecoverySignalingException>()));
    });

    test('reset fails pending requests', () async {
      final answer = signaling.sendUpdateMedia(
        callId: 'call-1',
        sessid: 'sess-1',
        sdp: 'offer',
      );

      signaling.reset();

      await expectLater(answer, throwsA(isA<RecoverySignalingException>()));
      expect(signaling.pendingCount, 0);
    });
  });

  group('legacy updateMedia handling', () {
    Map<String, dynamic> updateMedia(String sdp) => <String, dynamic>{
          'result': {'action': 'updateMedia', 'callID': 'call-1', 'sdp': sdp},
        };

    test('owns every updateMedia response for a call with a pending request',
        () async {
      final answer = signaling.sendUpdateMedia(
        callId: 'call-1',
        sessid: 'sess-1',
        sdp: 'offer',
      );

      expect(signaling.onResponse('other', updateMedia('stale')), isFalse);
      expect(signaling.ownsUpdateMediaResponse('other', 'call-1'), isTrue);
      expect(
        signaling.ownsUpdateMediaResponse('other', 'call-2'),
        isFalse,
        reason: 'another call keeps legacy handling',
      );

      signaling.onResponse(sent.single['id'] as String, updateMedia('answer'));
      expect(await answer, 'answer');
      expect(signaling.ownsUpdateMediaResponse('later', 'call-1'), isFalse);
    });

    test('a response without an id resolves the single pending request',
        () async {
      final answer = signaling.sendUpdateMedia(
        callId: 'call-1',
        sessid: 'sess-1',
        sdp: 'offer',
      );

      expect(signaling.onResponse(null, updateMedia('answer')), isTrue);
      expect(await answer, 'answer');
    });

    test('answered, expired and reset request ids stay recovery-owned',
        () async {
      final answered = signaling.sendUpdateMedia(
        callId: 'call-1',
        sessid: 'sess-1',
        sdp: 'offer',
      );
      final answeredId = sent.last['id'] as String;
      signaling.onResponse(answeredId, updateMedia('answer'));
      await answered;

      final short = RecoverySignaling(
        send: (message) =>
            sent.add(jsonDecode(message) as Map<String, dynamic>),
        requestExpiry: const Duration(milliseconds: 10),
      );
      final expired = short.sendUpdateMedia(
        callId: 'call-1',
        sessid: 'sess-1',
        sdp: 'offer',
      );
      final expiredId = sent.last['id'] as String;
      await expectLater(expired, throwsA(isA<TimeoutException>()));

      final reset = signaling.sendUpdateMedia(
        callId: 'call-1',
        sessid: 'sess-1',
        sdp: 'offer',
      );
      final resetId = sent.last['id'] as String;
      signaling.reset();
      await expectLater(reset, throwsA(isA<RecoverySignalingException>()));

      expect(signaling.onResponse(answeredId, updateMedia('dup')), isFalse);
      expect(signaling.ownsUpdateMediaResponse(answeredId, 'call-1'), isTrue);
      expect(short.ownsUpdateMediaResponse(expiredId, 'call-1'), isTrue);
      expect(signaling.ownsUpdateMediaResponse(resetId, 'call-1'), isTrue);
      expect(
        signaling.ownsUpdateMediaResponse('legacy', 'call-1'),
        isFalse,
        reason: 'unrelated legacy renegotiation keeps working',
      );
    });

    test('a request that could not be sent is retired', () async {
      final failing = RecoverySignaling(
        send: (_) => throw StateError('socket closed'),
      );
      await expectLater(
        failing.sendUpdateMedia(callId: 'call-1', sessid: 's', sdp: 'o'),
        throwsA(isA<RecoverySignalingException>()),
      );
      expect(failing.pendingCount, 0);
      expect(failing.ownsUpdateMediaResponse(null, 'call-1'), isFalse);
    });
  });

  group('inboundAudioPacketsFromReports', () {
    StatsReport report(String type, Map<String, dynamic> values) =>
        StatsReport('id-$type-${values.hashCode}', type, 0, values);

    test('sums inbound audio packets only', () {
      final packets = inboundAudioPacketsFromReports(<StatsReport>[
        report('inbound-rtp', {'kind': 'audio', 'packetsReceived': 120}),
        report('inbound-rtp', {'mediaType': 'audio', 'packetsReceived': '30'}),
        report('inbound-rtp', {'kind': 'video', 'packetsReceived': 999}),
        report('outbound-rtp', {'kind': 'audio', 'packetsSent': 500}),
      ]);

      expect(packets, 150);
    });

    test('returns null without an inbound audio counter', () {
      expect(
        inboundAudioPacketsFromReports(<StatsReport>[
          report('outbound-rtp', {'kind': 'audio', 'packetsSent': 1}),
        ]),
        isNull,
      );
    });
  });
}
