import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/src/recovery/call_recovery_monitor.dart';
import 'package:telnyx_webrtc/src/recovery/ice_restart_support.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

class _FakeTxSocket extends TxSocket {
  _FakeTxSocket() : super('wss://example.test');

  @override
  void connect() {}

  @override
  void close() {}

  @override
  void send(dynamic data) {}

  void emitOpen() => onOpen();
}

StatsReport _report(String id, String type, Map<String, dynamic> values) =>
    StatsReport(id, type, 0, values);

const _vpnHost = CandidateEvidence(
  callId: 'call-1',
  localCandidateType: 'host',
  localNetworkType: 'vpn',
);

void main() {
  group('selectedCandidateEvidenceFromReports', () {
    test('follows the transport selectedCandidatePairId', () {
      final evidence = selectedCandidateEvidenceFromReports(
        <StatsReport>[
          _report('T1', 'transport', {'selectedCandidatePairId': 'P2'}),
          _report('P1', 'candidate-pair', {
            'localCandidateId': 'L1',
            'remoteCandidateId': 'R1',
            'nominated': true,
            'state': 'succeeded',
          }),
          _report('P2', 'candidate-pair', {
            'localCandidateId': 'L2',
            'remoteCandidateId': 'R2',
          }),
          _report('L1', 'local-candidate', {'candidateType': 'relay'}),
          _report('L2', 'local-candidate', {
            'candidateType': 'host',
            'networkType': 'vpn',
            'address': '10.8.0.2',
            'protocol': 'udp',
          }),
          _report('R2', 'remote-candidate', {'candidateType': 'srflx'}),
        ],
        callId: 'call-1',
      )!;

      expect(evidence.callId, 'call-1');
      expect(evidence.localCandidateType, 'host');
      expect(evidence.localNetworkType, 'vpn');
      expect(evidence.localAddress, '10.8.0.2');
      expect(evidence.localProtocol, 'udp');
      expect(evidence.remoteCandidateType, 'srflx');
    });

    test('falls back to a nominated, succeeded pair', () {
      final evidence = selectedCandidateEvidenceFromReports(<StatsReport>[
        _report('P1', 'candidate-pair', {
          'localCandidateId': 'L1',
          'nominated': true,
          'state': 'in-progress',
        }),
        _report('P2', 'candidate-pair', {
          'localCandidateId': 'L2',
          'nominated': true,
          'state': 'succeeded',
        }),
        _report('L1', 'local-candidate', {'candidateType': 'relay'}),
        _report('L2', 'local-candidate', {'candidateType': 'srflx'}),
      ]);

      expect(evidence!.localCandidateType, 'srflx');
    });

    test('returns null without a selected pair or local candidate', () {
      expect(selectedCandidateEvidenceFromReports(<StatsReport>[]), isNull);
      expect(
        selectedCandidateEvidenceFromReports(<StatsReport>[
          _report('P1', 'candidate-pair', {
            'localCandidateId': 'missing',
            'selected': true,
          }),
        ]),
        isNull,
      );
    });
  });

  group('shouldForceRelayForEvidence', () {
    test('only a non-relay candidate on an explicit VPN qualifies', () {
      expect(shouldForceRelayForEvidence(_vpnHost), isTrue);
      expect(
        shouldForceRelayForEvidence(
          const CandidateEvidence(
            localCandidateType: 'relay',
            localNetworkType: 'vpn',
          ),
        ),
        isFalse,
      );
      expect(
        shouldForceRelayForEvidence(
          const CandidateEvidence(
            localCandidateType: 'host',
            localNetworkType: 'wifi',
          ),
        ),
        isFalse,
      );
      expect(
        shouldForceRelayForEvidence(
          const CandidateEvidence(localCandidateType: 'host'),
        ),
        isFalse,
        reason: 'fail closed without VPN evidence',
      );
    });
  });

  group('client relay override and network path changes', () {
    late TelnyxClient client;
    late _FakeTxSocket socket;
    late StreamController<List<ConnectivityResult>> connectivity;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      socket = _FakeTxSocket();
      connectivity = StreamController<List<ConnectivityResult>>.broadcast();
      client = TelnyxClient(connectivityChanges: () => connectivity.stream)
        ..txSocket = socket
        ..connectWithCredential(
          CredentialConfig(
            sipUser: 'user',
            sipPassword: 'pass',
            sipCallerIDName: 'name',
            sipCallerIDNumber: 'number',
            logLevel: LogLevel.none,
            debug: false,
            autoReconnect: true,
          ),
        );
      await pumpEventQueue();
      socket.emitOpen();
    });

    tearDown(() async {
      client.dispose();
      await connectivity.close();
    });

    test('VPN evidence arms a one-shot override; other evidence clears it', () {
      client.recordRecoveryCandidateEvidence('call-1', _vpnHost);
      expect(client.hasRecoveryRelayOverrideForTest('call-1'), isTrue);

      client.recordRecoveryCandidateEvidence(
        'call-1',
        const CandidateEvidence(
          localCandidateType: 'host',
          localNetworkType: 'wifi',
        ),
      );
      expect(client.hasRecoveryRelayOverrideForTest('call-1'), isFalse);
    });

    test('a failed reattach drops the override', () async {
      client.recordRecoveryCandidateEvidence('call-1', _vpnHost);
      final reattach = client.requestRecoveryReattach('call-1');

      client.disconnect();

      expect(await reattach, isFalse);
      expect(client.hasRecoveryRelayOverrideForTest('call-1'), isFalse);
    });

    test('a network switch cancels a running recovery episode', () async {
      final call = client.call..callId = 'call-1';
      client.calls['call-1'] = call;
      call.callHandler.changeState(CallState.active);
      final monitor = call.recoveryMonitor!;
      expect(monitor.state, CallRecoveryState.idle);

      // Stale signaling: the failure starts a probing episode.
      monitor.onIceConnectionStateChanged(
        RTCIceConnectionState.RTCIceConnectionStateFailed,
      );
      await pumpEventQueue();
      expect(monitor.state, CallRecoveryState.probing);
      final generation = monitor.generation;

      connectivity.add([ConnectivityResult.wifi]);
      await pumpEventQueue();
      connectivity.add([ConnectivityResult.mobile]);
      await pumpEventQueue();

      expect(monitor.state, CallRecoveryState.idle);
      expect(monitor.generation, greaterThan(generation));
      expect(client.isRecoveryReconnecting, isTrue);
    });
  });
}
