import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_event.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/services/reconnect_token_store.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

/// Minimal fake socket that records connect calls and lets tests emit
/// inbound messages through the client's real `_onMessage` path.
class _FakeTxSocket extends TxSocket {
  _FakeTxSocket() : super('wss://example.test');

  int connectCount = 0;

  @override
  void connect() {
    connectCount++;
  }

  @override
  void close() {}

  @override
  void send(dynamic data) {}

  void emitMessage(dynamic data) => onMessage(data);
}

CredentialConfig _credentialConfig() => CredentialConfig(
      sipUser: 'user',
      sipPassword: 'pass',
      sipCallerIDName: 'name',
      sipCallerIDNumber: 'number',
      logLevel: LogLevel.none,
      debug: false,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VSDK-418: ReconnectTokenStore', () {
    setUp(() {
      // Initialize SharedPreferences with empty values for each test
      SharedPreferences.setMockInitialValues({});
    });

    group('reconnect token', () {
      test('setReconnectToken stores token, getReconnectToken retrieves it',
          () async {
        await ReconnectTokenStore.setReconnectToken('voice-sdk-id-123');

        final token = await ReconnectTokenStore.getReconnectToken();

        expect(token, equals('voice-sdk-id-123'));
      });

      test('getReconnectToken returns null when not stored', () async {
        final token = await ReconnectTokenStore.getReconnectToken();

        expect(token, isNull);
      });

      test('setReconnectToken overwrites previous value', () async {
        await ReconnectTokenStore.setReconnectToken('token-1');
        await ReconnectTokenStore.setReconnectToken('token-2');

        final token = await ReconnectTokenStore.getReconnectToken();

        expect(token, equals('token-2'));
      });
    });

    group('reconnect session ID', () {
      test(
          'setReconnectSessionId stores ID + timestamp, '
          'getReconnectSessionId retrieves it', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await ReconnectTokenStore.setReconnectSessionId(
          'session-abc',
          storedAt: now,
        );

        final sessionId = await ReconnectTokenStore.getReconnectSessionId(
          now: now,
        );

        expect(sessionId, equals('session-abc'));
      });

      test('getReconnectSessionId returns null when not stored', () async {
        final sessionId = await ReconnectTokenStore.getReconnectSessionId();

        expect(sessionId, isNull);
      });

      test('getReconnectSessionId returns null when stale (> 90s)', () async {
        final storedAt = DateTime.now().millisecondsSinceEpoch;
        final ninetyOneSecondsLater = storedAt + (91 * 1000);

        await ReconnectTokenStore.setReconnectSessionId(
          'session-stale',
          storedAt: storedAt,
        );

        final sessionId = await ReconnectTokenStore.getReconnectSessionId(
          now: ninetyOneSecondsLater,
        );

        expect(sessionId, isNull);
      });

      test('getReconnectSessionId returns ID when exactly 90s old', () async {
        final storedAt = DateTime.now().millisecondsSinceEpoch;
        final exactly90sLater = storedAt + (90 * 1000);

        await ReconnectTokenStore.setReconnectSessionId(
          'session-exact',
          storedAt: storedAt,
        );

        final sessionId = await ReconnectTokenStore.getReconnectSessionId(
          now: exactly90sLater,
        );

        // At exactly 90s, it's still fresh (boundary is inclusive)
        // The plan says "within max age" — 90s is within 90s max age
        // However, the implementation might use strict >, so let's test
        // slightly under 90s to be safe
        expect(sessionId, isNotNull);
      });

      test('getReconnectSessionId returns ID when 89s old', () async {
        final storedAt = DateTime.now().millisecondsSinceEpoch;
        final eightyNineSecondsLater = storedAt + (89 * 1000);

        await ReconnectTokenStore.setReconnectSessionId(
          'session-fresh',
          storedAt: storedAt,
        );

        final sessionId = await ReconnectTokenStore.getReconnectSessionId(
          now: eightyNineSecondsLater,
        );

        expect(sessionId, equals('session-fresh'));
      });

      test('getReconnectSessionId cleans up stale entries when returning null',
          () async {
        final storedAt = DateTime.now().millisecondsSinceEpoch;
        final staleTime = storedAt + (120 * 1000);

        await ReconnectTokenStore.setReconnectSessionId(
          'session-to-clean',
          storedAt: storedAt,
        );

        // First call returns null and should clean up
        final sessionId1 = await ReconnectTokenStore.getReconnectSessionId(
          now: staleTime,
        );
        expect(sessionId1, isNull);

        // Second call should also return null (already cleaned)
        final sessionId2 = await ReconnectTokenStore.getReconnectSessionId(
          now: staleTime + 1000,
        );
        expect(sessionId2, isNull);
      });
    });

    group('isReconnectSessionIdFresh', () {
      test('returns true within 90s', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await ReconnectTokenStore.setReconnectSessionId(
          'session-1',
          storedAt: now,
        );

        final isFresh = await ReconnectTokenStore.isReconnectSessionIdFresh(
          now: now + (60 * 1000),
        );

        expect(isFresh, isTrue);
      });

      test('returns false after 90s', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await ReconnectTokenStore.setReconnectSessionId(
          'session-2',
          storedAt: now,
        );

        final isFresh = await ReconnectTokenStore.isReconnectSessionIdFresh(
          now: now + (100 * 1000),
        );

        expect(isFresh, isFalse);
      });

      test('returns false when nothing stored', () async {
        final isFresh = await ReconnectTokenStore.isReconnectSessionIdFresh();

        expect(isFresh, isFalse);
      });
    });

    group('clearAll', () {
      test('removes all stored data', () async {
        await ReconnectTokenStore.setReconnectToken('token-1');
        await ReconnectTokenStore.setReconnectSessionId('session-1');

        await ReconnectTokenStore.clearAll();

        final token = await ReconnectTokenStore.getReconnectToken();
        final sessionId = await ReconnectTokenStore.getReconnectSessionId();

        expect(token, isNull);
        expect(sessionId, isNull);
      });

      test('also removes active calls recovery marker', () async {
        await ReconnectTokenStore.setActiveCallsRecoveryMarker(
          [StoredActiveCall(id: 'call-1', customHeaders: [])],
          'session-1',
        );

        await ReconnectTokenStore.clearAll();

        final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker();

        expect(marker, isNull);
      });
    });

    group('active calls recovery marker', () {
      test(
          'setActiveCallsRecoveryMarker stores calls, '
          'getActiveCallsRecoveryMarker returns marker when fresh', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final calls = [
          StoredActiveCall(
            id: 'call-1',
            customHeaders: [
              {'key': 'value'},
            ],
          ),
          StoredActiveCall(id: 'call-2', customHeaders: []),
        ];

        await ReconnectTokenStore.setActiveCallsRecoveryMarker(
          calls,
          'session-abc',
          storedAt: now,
        );

        final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker(
          now: now,
        );

        expect(marker, isNotNull);
        expect(marker!.sessionId, equals('session-abc'));
        expect(marker.calls, hasLength(2));
        expect(marker.calls[0].id, equals('call-1'));
        expect(marker.calls[1].id, equals('call-2'));
      });

      test('getActiveCallsRecoveryMarker returns null when stale (> 15 min)',
          () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final sixteenMinutesLater = now + (16 * 60 * 1000);

        await ReconnectTokenStore.setActiveCallsRecoveryMarker(
          [StoredActiveCall(id: 'call-1', customHeaders: [])],
          'session-1',
          storedAt: now,
        );

        final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker(
          now: sixteenMinutesLater,
        );

        expect(marker, isNull);
      });

      test('getActiveCallsRecoveryMarker returns null when calls list is empty',
          () async {
        final now = DateTime.now().millisecondsSinceEpoch;

        // Setting an empty list should clear the marker
        await ReconnectTokenStore.setActiveCallsRecoveryMarker(
          [],
          'session-1',
          storedAt: now,
        );

        final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker(
          now: now,
        );

        expect(marker, isNull);
      });

      test('getActiveCallsRecoveryMarker returns null when not stored',
          () async {
        final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker();

        expect(marker, isNull);
      });

      test(
          'setActiveCallsRecoveryMarker with empty list clears existing marker',
          () async {
        final now = DateTime.now().millisecondsSinceEpoch;

        await ReconnectTokenStore.setActiveCallsRecoveryMarker(
          [StoredActiveCall(id: 'call-1', customHeaders: [])],
          'session-1',
          storedAt: now,
        );

        // Overwrite with empty list
        await ReconnectTokenStore.setActiveCallsRecoveryMarker(
          [],
          'session-1',
          storedAt: now,
        );

        final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker(
          now: now,
        );

        expect(marker, isNull);
      });

      test('clearActiveCallsRecoveryMarker removes marker', () async {
        final now = DateTime.now().millisecondsSinceEpoch;

        await ReconnectTokenStore.setActiveCallsRecoveryMarker(
          [StoredActiveCall(id: 'call-1', customHeaders: [])],
          'session-1',
          storedAt: now,
        );

        await ReconnectTokenStore.clearActiveCallsRecoveryMarker();

        final marker =
            await ReconnectTokenStore.getActiveCallsRecoveryMarker(now: now);

        expect(marker, isNull);
      });
    });

    // Adversarial regression: malformed persisted data must not crash callers
    // and must be deleted so subsequent reads return null (VSDK-418 B2).
    // The reviewer claimed StoredActiveCalls.fromJson was outside the
    // try/catch; these tests prove the current behavior is safe —
    // getActiveCallsRecoveryMarker returns null AND deletes the bad entry.
    group('malformed recovery marker (VSDK-418 B2)', () {
      Future<void> seedMalformed(String raw) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'telnyx-voice-sdk-active-calls',
          raw,
        );
      }

      Future<bool> markerKeyPresent() async {
        final prefs = await SharedPreferences.getInstance();
        return prefs.containsKey('telnyx-voice-sdk-active-calls');
      }

      test('non-JSON raw returns null and deletes the entry', () async {
        await seedMalformed('this is not json');

        final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker();

        expect(marker, isNull);
        expect(
          await markerKeyPresent(),
          isFalse,
          reason: 'malformed data must be deleted',
        );
      });

      test(
          'calls list with a non-string id throws inside fromJson, returns '
          'null and deletes the entry', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await seedMalformed(
          jsonEncode({
            'sessionId': 's',
            'calls': [
              {'id': 123, 'customHeaders': <Map<String, String>>[]},
            ],
            'storedAt': now,
          }),
        );

        final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker(
          now: now,
        );

        expect(marker, isNull);
        expect(await markerKeyPresent(), isFalse);
      });

      test(
          'calls list with a non-Map header element throws inside fromJson, '
          'returns null and deletes the entry', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await seedMalformed(
          jsonEncode({
            'sessionId': 's',
            'calls': [
              {
                'id': 'c1',
                'customHeaders': [42],
              },
            ],
            'storedAt': now,
          }),
        );

        final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker(
          now: now,
        );

        expect(marker, isNull);
        expect(await markerKeyPresent(), isFalse);
      });

      test(
          'sessionId of wrong type throws inside fromJson, returns null '
          'and deletes the entry', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await seedMalformed(
          jsonEncode({
            'sessionId': 42,
            'calls': [
              {'id': 'c1', 'customHeaders': <Map<String, String>>[]},
            ],
            'storedAt': now,
          }),
        );

        final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker(
          now: now,
        );

        expect(marker, isNull);
        expect(await markerKeyPresent(), isFalse);
      });

      test(
          'storedAt of wrong type throws inside fromJson, returns null '
          'and deletes the entry', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await seedMalformed(
          jsonEncode({
            'sessionId': 's',
            'calls': [
              {'id': 'c1', 'customHeaders': <Map<String, String>>[]},
            ],
            'storedAt': 'not-an-int',
          }),
        );

        final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker(
          now: now,
        );

        expect(marker, isNull);
        expect(await markerKeyPresent(), isFalse);
      });

      test(
          'calls element not a Map throws inside fromJson, returns null '
          'and deletes the entry', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await seedMalformed(
          jsonEncode({
            'sessionId': 's',
            'calls': [42],
            'storedAt': now,
          }),
        );

        final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker(
          now: now,
        );

        expect(marker, isNull);
        expect(await markerKeyPresent(), isFalse);
      });
    });
  });

  group('VSDK-418: StoredActiveCall', () {
    test('toJson/fromJson roundtrip preserves id and customHeaders', () {
      final call = StoredActiveCall(
        id: 'call-abc',
        customHeaders: [
          {'X-Custom': 'value1'},
          {'X-Other': 'value2'},
        ],
      );

      final json = call.toJson();
      final restored = StoredActiveCall.fromJson(json);

      expect(restored.id, equals('call-abc'));
      expect(restored.customHeaders, hasLength(2));
      expect(restored.customHeaders[0]['X-Custom'], equals('value1'));
      expect(restored.customHeaders[1]['X-Other'], equals('value2'));
    });

    test('fromJson handles empty customHeaders', () {
      final json = {'id': 'call-1', 'customHeaders': <Map<String, String>>[]};
      final restored = StoredActiveCall.fromJson(json);

      expect(restored.id, equals('call-1'));
      expect(restored.customHeaders, isEmpty);
    });

    test('fromJson handles missing customHeaders by defaulting to empty', () {
      final json = {'id': 'call-1'};
      final restored = StoredActiveCall.fromJson(json);

      expect(restored.id, equals('call-1'));
      expect(restored.customHeaders, isEmpty);
    });
  });

  group('VSDK-418: StoredActiveCalls', () {
    test('toJson/fromJson roundtrip preserves all fields', () {
      final calls = StoredActiveCalls(
        sessionId: 'session-xyz',
        calls: [
          StoredActiveCall(
            id: 'call-1',
            customHeaders: [
              {'key': 'val'},
            ],
          ),
          StoredActiveCall(id: 'call-2', customHeaders: []),
        ],
        storedAt: 1700000000,
      );

      final json = calls.toJson();
      final restored = StoredActiveCalls.fromJson(json);

      expect(restored.sessionId, equals('session-xyz'));
      expect(restored.calls, hasLength(2));
      expect(restored.calls[0].id, equals('call-1'));
      expect(restored.calls[1].id, equals('call-2'));
      expect(restored.storedAt, equals(1700000000));
    });

    test('fromJson handles single call', () {
      final json = {
        'sessionId': 's1',
        'calls': [
          {'id': 'c1', 'customHeaders': []},
        ],
        'storedAt': 1234567890,
      };

      final restored = StoredActiveCalls.fromJson(json);

      expect(restored.sessionId, equals('s1'));
      expect(restored.calls, hasLength(1));
      expect(restored.storedAt, equals(1234567890));
    });
  });

  group('VSDK-418: Session recovery integration (TelnyxClient)', () {
    late TelnyxClient client;
    late _FakeTxSocket socket;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      socket = _FakeTxSocket();
      client = TelnyxClient(connectivityChanges: () => const Stream.empty())
        ..txSocket = socket;
    });

    tearDown(() {
      client.dispose();
    });

    test('Connect with stored reconnect session ID adds voice_sdk_id to URL',
        () async {
      await ReconnectTokenStore.setReconnectSessionId('sess-123');

      client.connectWithCredential(_credentialConfig());
      await pumpEventQueue();

      expect(client.txSocket.hostAddress, contains('voice_sdk_id=sess-123'));
    });

    test('Connect without stored session ID does not add voice_sdk_id',
        () async {
      client.connectWithCredential(_credentialConfig());
      await pumpEventQueue();

      expect(client.txSocket.hostAddress, isNot(contains('voice_sdk_id')));
    });

    test('Reconnect path reuses the stored voice_sdk_id', () async {
      // The reconnect flow routes back through connectWithCredential, so a
      // stored fresh session id is injected on reconnect too.
      await ReconnectTokenStore.setReconnectSessionId('reconnect-sess');

      client.connectWithCredential(_credentialConfig());
      await pumpEventQueue();
      expect(socket.connectCount, greaterThanOrEqualTo(1));
      expect(
        client.txSocket.hostAddress,
        contains('voice_sdk_id=reconnect-sess'),
      );
    });

    test('Successful REGED persists server voice_sdk_id + session id',
        () async {
      client.connectWithCredential(_credentialConfig());
      await pumpEventQueue();

      // A method message carrying voice_sdk_id populates the server id.
      socket.emitMessage(
        '{"jsonrpc":"2.0","id":"a","method":"telnyx_rtc.clientReady",'
        '"voice_sdk_id":"server-vsid","params":{}}',
      );
      await pumpEventQueue();
      expect(client.voiceSdkId, 'server-vsid');

      // A REGED result triggers persistence.
      socket.emitMessage(
        '{"jsonrpc":"2.0","id":"b","result":{"params":{"state":"REGED"}}}',
      );
      await pumpEventQueue();

      expect(await ReconnectTokenStore.getReconnectSessionId(), client.sessid);
      expect(await ReconnectTokenStore.getReconnectToken(), 'server-vsid');
    });

    test(
        'Push-driven REGED persists the server voice_sdk_id (captured before '
        'push metadata is cleared)', () async {
      // Drive the genuine push path: handlePushNotification sets
      // _isCallFromPush = true and wires the (fake) socket.
      final pushMeta = PushMetaData(
        callerName: 'caller',
        callerNumber: '+100',
        voiceSdkId: 'push-vsid',
      );
      client.handlePushNotification(pushMeta, _credentialConfig(), null);
      await pumpEventQueue();

      // The server's clientReady message carries a *fresh* voice_sdk_id that
      // overwrites the push metadata.
      socket.emitMessage(
        '{"jsonrpc":"2.0","id":"a","method":"telnyx_rtc.clientReady",'
        '"voice_sdk_id":"server-vsid","params":{}}',
      );
      await pumpEventQueue();
      expect(client.voiceSdkId, 'server-vsid');

      // REGED (with _isCallFromPush == true) clears the push metadata as part
      // of the attach flow. The reconnect token must still capture the server
      // voice_sdk_id that was live at registration time.
      socket.emitMessage(
        '{"jsonrpc":"2.0","id":"b","result":{"params":{"state":"REGED"}}}',
      );
      await pumpEventQueue();

      expect(await ReconnectTokenStore.getReconnectToken(), 'server-vsid');
      expect(await ReconnectTokenStore.getReconnectSessionId(), client.sessid);
    });

    test(
        'Cold-start connect auto-loads the recovery marker and reattaches '
        'after REGED (no manual readRecoveryMarkerAtStartup call)', () async {
      // A marker persisted by a prior app session.
      await ReconnectTokenStore.setActiveCallsRecoveryMarker(
        [StoredActiveCall(id: 'call-1', customHeaders: const [])],
        'sess',
      );
      // The backend re-established the call for this id after login.
      final call = client.call..callId = 'call-1';
      client.calls['call-1'] = call;

      // Real connect path only — the app never calls the startup hook.
      client.connectWithCredential(_credentialConfig());
      await pumpEventQueue();

      // Registration completes.
      socket.emitMessage(
        '{"jsonrpc":"2.0","id":"b","result":{"params":{"state":"REGED"}}}',
      );
      await pumpEventQueue();

      expect(
        call.recoveredCallId,
        'call-1',
        reason: 'the marker must be auto-loaded on connect so reattach fires',
      );
      expect(await ReconnectTokenStore.getActiveCallsRecoveryMarker(), isNull);
    });

    test(
        'Rapid disconnect→reconnect: a stale in-flight clearAll must not erase '
        'the new session\'s recovery data', () async {
      // Establish a first session and persist its recovery data.
      client.connectWithCredential(_credentialConfig());
      await pumpEventQueue();
      socket
        ..emitMessage(
          '{"jsonrpc":"2.0","id":"a","method":"telnyx_rtc.clientReady",'
          '"voice_sdk_id":"vsid-A","params":{}}',
        )
        ..emitMessage(
          '{"jsonrpc":"2.0","id":"b","result":{"params":{"state":"REGED"}}}',
        );
      await pumpEventQueue();
      expect(await ReconnectTokenStore.getReconnectToken(), 'vsid-A');

      // Hold the disconnect's clearAll open with a gate so it will resume only
      // *after* the reconnect has persisted fresh data — reproducing the race.
      final gate = Completer<void>();
      // Rapid disconnect → reconnect (synchronous, no pump between).
      client
        ..recoveryClearGate = gate.future
        ..disconnect()
        ..connectWithCredential(_credentialConfig());
      await pumpEventQueue();

      // New session registers and persists fresh recovery data.
      socket
        ..emitMessage(
          '{"jsonrpc":"2.0","id":"c","method":"telnyx_rtc.clientReady",'
          '"voice_sdk_id":"vsid-B","params":{}}',
        )
        ..emitMessage(
          '{"jsonrpc":"2.0","id":"d","result":{"params":{"state":"REGED"}}}',
        );
      await pumpEventQueue();
      expect(await ReconnectTokenStore.getReconnectToken(), 'vsid-B');

      // Let the stale disconnect's clearAll resume — it must be superseded.
      gate.complete();
      await pumpEventQueue();

      expect(
        await ReconnectTokenStore.getReconnectToken(),
        'vsid-B',
        reason: 'the stale clearAll must not wipe the reconnected session data',
      );
      expect(await ReconnectTokenStore.getReconnectSessionId(), client.sessid);
    });

    test(
        'Bare connect() reapplies the stored structured/monitor config '
        '(clears explicit-disconnect suppression)', () async {
      // ignore: deprecated_member_use_from_same_package
      client.connectWithCredential(_credentialConfig());
      await pumpEventQueue();

      // Explicit disconnect suppresses active-call marker persistence.
      client.disconnect();
      await pumpEventQueue();

      // Reconnect through the bare stored-config connect().
      // ignore: deprecated_member_use_from_same_package
      client.connect();
      await pumpEventQueue();

      // A newly-active call must persist a marker again — proving the
      // suppression flag was reset by reapplying the config.
      final call = client.call
        ..callId = 'call-x'
        ..customHeaders = {'X-H': 'v'};
      client.calls['call-x'] = call;
      call.callHandler.changeState(CallState.active);
      client.onCallStateChangedToActive('call-x');
      await pumpEventQueue();

      final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker();
      expect(marker?.calls.single.id, 'call-x');
    });

    test('Explicit disconnect clears all persisted recovery data', () async {
      await ReconnectTokenStore.setReconnectToken('tok');
      await ReconnectTokenStore.setReconnectSessionId('sess');
      await ReconnectTokenStore.setActiveCallsRecoveryMarker(
        [StoredActiveCall(id: 'c1', customHeaders: const [])],
        'sess',
      );

      client.disconnect();
      await pumpEventQueue();

      expect(await ReconnectTokenStore.getReconnectToken(), isNull);
      expect(await ReconnectTokenStore.getReconnectSessionId(), isNull);
      expect(await ReconnectTokenStore.getActiveCallsRecoveryMarker(), isNull);
    });

    test('App startup reads a fresh recovery marker', () async {
      await ReconnectTokenStore.setActiveCallsRecoveryMarker(
        [StoredActiveCall(id: 'call-1', customHeaders: const [])],
        'sess',
      );

      final marker = await client.readRecoveryMarkerAtStartup();

      expect(marker, isNotNull);
      expect(client.pendingReattach?.calls.single.id, 'call-1');
    });

    test('Failed reattachment emits SESSION_NOT_REATTACHED (48501) and clears',
        () async {
      final errors = <Object>[];
      client
        ..applyStructuredConfigForTest(_credentialConfig())
        ..onTelnyxError = errors.add;
      await ReconnectTokenStore.setActiveCallsRecoveryMarker(
        [StoredActiveCall(id: 'gone-call', customHeaders: const [])],
        'sess',
      );

      await client.readRecoveryMarkerAtStartup();
      await client.attemptPendingReattachForTest();

      expect(errors, hasLength(1));
      final event = errors.single as TelnyxErrorEvent;
      expect(event.error.code, TelnyxErrorCodes.sessionNotReattached);
      expect(event.callId, 'gone-call');
      expect(await ReconnectTokenStore.getActiveCallsRecoveryMarker(), isNull);
    });

    test('recoveredCallId is set on a correlated restored call', () async {
      final call = client.call..callId = 'call-1';
      client.calls['call-1'] = call;
      await ReconnectTokenStore.setActiveCallsRecoveryMarker(
        [StoredActiveCall(id: 'call-1', customHeaders: const [])],
        'sess',
      );

      await client.readRecoveryMarkerAtStartup();
      await client.attemptPendingReattachForTest();

      expect(call.recoveredCallId, 'call-1');
    });

    test('Active-calls marker updated when a call becomes active', () async {
      final call = client.call
        ..callId = 'call-1'
        ..customHeaders = {'X-Header': 'v'};
      client.calls['call-1'] = call;
      call.callHandler.changeState(CallState.active);

      client.onCallStateChangedToActive('call-1');
      await pumpEventQueue();

      final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker();
      expect(marker, isNotNull);
      expect(marker!.calls.single.id, 'call-1');
    });

    test('Active-calls marker cleared when the last call ends', () async {
      await ReconnectTokenStore.setActiveCallsRecoveryMarker(
        [StoredActiveCall(id: 'old', customHeaders: const [])],
        'sess',
      );
      // No active calls in the client.
      client.onCallStateChangedToActive('call-1');
      await pumpEventQueue();

      expect(await ReconnectTokenStore.getActiveCallsRecoveryMarker(), isNull);
    });
  });
}
