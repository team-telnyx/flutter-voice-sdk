import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/tx_ice_server.dart';
import 'package:telnyx_webrtc/model/audio_constraints.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_collector.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';

void main() {
  group('ClientSummary', () {
    group('fromConfig with CredentialConfig', () {
      late CredentialConfig config;
      late List<TxIceServer> iceServers;

      setUp(() {
        config = CredentialConfig(
          sipUser: 'test_user',
          sipPassword: 'test_pass',
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '1234567890',
          debug: true,
          logLevel: LogLevel.all,
        );
        iceServers = [
          TxIceServer(
            urls: ['turn:turn.telnyx.com:3478?transport=tcp'],
            username: 'turnuser',
            credential: 'turnpass',
          ),
          TxIceServer(urls: ['stun:stun.telnyx.com:3478']),
        ];
      });

      test('builds with loginPassword auth type', () {
        final summary = ClientSummary.fromConfig(
          config: config,
          iceServers: iceServers,
          host: 'wss://rtc.telnyx.com:443',
        );

        expect(summary.authentication, isNotNull);
        expect(summary.authentication!.type, AuthenticationType.loginPassword);
      });

      test('includes connection info', () {
        final summary = ClientSummary.fromConfig(
          config: config,
          iceServers: iceServers,
          host: 'wss://rtc.telnyx.com:443',
        );

        expect(summary.connection, isNotNull);
        expect(summary.connection!.host, 'wss://rtc.telnyx.com:443');
        expect(summary.connection!.env, 'production');
        expect(summary.connection!.autoReconnect, true);
        expect(summary.connection!.maxReconnectAttempts, 10);
        expect(summary.connection!.region, 'auto');
        expect(summary.connection!.keepConnectionAliveOnSocketClose, false);
        expect(summary.connection!.hangupOnBeforeUnload, true);
        expect(summary.connection!.useCanaryRtcServer, false);
        expect(summary.connection!.skipLastVoiceSdkId, false);
        expect(summary.connection!.skipTrailing, false);
      });

      test('sanitizes ICE servers - preserves URLs, redacts credentials', () {
        final summary = ClientSummary.fromConfig(
          config: config,
          iceServers: iceServers,
        );

        expect(summary.media, isNotNull);
        expect(summary.media!.iceServers, isNotNull);
        expect(summary.media!.iceServers!.length, 2);

        final turn = summary.media!.iceServers![0];
        expect(turn.urls, ['turn:turn.telnyx.com:3478?transport=tcp']);
        expect(turn.hasUsername, true);
        expect(turn.hasCredential, true);

        final stun = summary.media!.iceServers![1];
        expect(stun.urls, ['stun:stun.telnyx.com:3478']);
        expect(stun.hasUsername, false);
        expect(stun.hasCredential, false);
      });

      test('includes call report config', () {
        final summary = ClientSummary.fromConfig(
          config: config,
          iceServers: iceServers,
        );

        expect(summary.callReports, isNotNull);
        expect(summary.callReports!.enabled, true);
        expect(summary.callReports!.intervalMs, 5000);
        expect(summary.callReports!.flushIntervalMs, 180000);
        expect(summary.callReports!.debugLogLevel, 'debug');
        expect(summary.callReports!.debugLogMaxEntries, 1000);
      });

      test('includes media config', () {
        final audioConstraints = AudioConstraints(
          echoCancellation: true,
          noiseSuppression: false,
        );
        final summary = ClientSummary.fromConfig(
          config: config,
          iceServers: iceServers,
          useTrickleIce: true,
          mutedMicOnStart: true,
          audioConstraints: audioConstraints,
        );

        expect(summary.media, isNotNull);
        expect(summary.media!.audio, isTrue);
        expect(summary.media!.video, isFalse);
        expect(summary.media!.trickleIce, true);
        expect(summary.media!.mutedMicOnStart, true);
        expect(summary.media!.forceRelayCandidate, false);
        expect(summary.media!.prefetchIceCandidates, true);
      });

      test('adds authoritative resolved datacenter without losing config', () {
        final summary = ClientSummary.fromConfig(
          config: config,
          iceServers: const [],
          host: 'wss://rtc.telnyx.com:443',
        ).copyWithResolvedConnection(dc: 'ld6-prod', region: 'eu');

        expect(summary.connection!.dc, 'ld6-prod');
        expect(summary.connection!.region, 'eu');
        expect(summary.connection!.env, 'production');
        expect(summary.authentication!.type, AuthenticationType.loginPassword);
      });

      test('uses JS defaults and omits an empty ICE server list', () {
        final summary = ClientSummary.fromConfig(
          config: config,
          iceServers: const [],
        );

        expect(summary.media!.trickleIce, false);
        expect(summary.media!.iceServers, isNull);
        expect(summary.toJson()['media'].containsKey('iceServers'), isFalse);
      });

      test('toJson produces valid nested structure', () {
        final summary = ClientSummary.fromConfig(
          config: config,
          iceServers: iceServers,
          host: 'wss://rtc.telnyx.com:443',
        );

        final json = summary.toJson();

        expect(json['authentication'], isNotNull);
        expect(json['authentication']['type'], 'login_password');

        expect(json['connection'], isNotNull);
        expect(json['connection']['host'], 'wss://rtc.telnyx.com:443');
        expect(json['connection']['autoReconnect'], true);

        expect(json['media'], isNotNull);
        expect(json['media']['iceServers'], isNotNull);
        expect((json['media']['iceServers'] as List).length, 2);
        expect(json['media']['iceServers'][0]['hasUsername'], true);
        expect(json['media']['iceServers'][0]['hasCredential'], true);
        expect(json['media']['iceServers'][0]['urls'],
            ['turn:turn.telnyx.com:3478?transport=tcp']);

        expect(json['callReports'], isNotNull);
        expect(json['callReports']['enabled'], true);
      });
    });

    group('fromConfig with TokenConfig', () {
      test('builds with token auth type', () {
        final config = TokenConfig(
          sipToken: 'test_token',
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '1234567890',
          debug: true,
          logLevel: LogLevel.all,
        );

        final summary = ClientSummary.fromConfig(
          config: config,
          iceServers: [],
        );

        expect(summary.authentication!.type, AuthenticationType.token);
      });
    });

    group('CallSummary with clientSummary', () {
      test('toJson includes clientSummary when present', () {
        final clientSummary = ClientSummary(
          authentication: ClientAuthenticationSummary(
            type: AuthenticationType.token,
          ),
          connection: ClientConnectionSummary(
            host: 'wss://rtc.telnyx.com:443',
          ),
        );

        final callSummary = CallSummary(
          callId: 'test-call-id',
          direction: 'outbound',
          sdkVersion: VersionUtils.getSDKVersion(),
          clientSummary: clientSummary,
        );

        final json = callSummary.toJson();

        expect(json['callId'], 'test-call-id');
        expect(json['direction'], 'outbound');
        expect(json['clientSummary'], isNotNull);
        expect(json['clientSummary']['authentication']['type'], 'token');
        expect(json['clientSummary']['connection']['host'],
            'wss://rtc.telnyx.com:443');
      });

      test('toJson omits clientSummary when null', () {
        final callSummary = CallSummary(
          callId: 'test-call-id',
          direction: 'inbound',
          sdkVersion: VersionUtils.getSDKVersion(),
        );

        final json = callSummary.toJson();

        expect(json.containsKey('clientSummary'), isFalse);
      });

      test(
          'collector preserves clientSummary for final and intermediate reports',
          () {
        final clientSummary = ClientSummary(
          authentication: const ClientAuthenticationSummary(
            type: AuthenticationType.loginPassword,
          ),
        );
        final callSummary = CallSummary(
          callId: 'test-call-id',
          direction: 'outbound',
          sdkVersion: VersionUtils.getSDKVersion(),
          clientSummary: clientSummary,
        );
        final collector = CallReportCollector();

        collector.storeUploadConfig(
          callReportId: 'report-id',
          host: 'wss://rtc.telnyx.com',
          summary: callSummary,
        );
        final resolvedClientSummary = clientSummary.copyWithResolvedConnection(
          dc: 'ld6-prod',
        );
        collector.updateStoredCallMetadata(
          clientSummary: resolvedClientSummary,
          telnyxSessionId: 'session-id',
          telnyxLegId: 'leg-id',
        );

        expect(collector.storedSummaryForTesting?.clientSummary,
            same(resolvedClientSummary));
        expect(
            collector.storedSummaryForTesting?.telnyxSessionId, 'session-id');
        expect(collector.storedSummaryForTesting?.telnyxLegId, 'leg-id');
        expect(
          collector.buildFinalSummary(callSummary).clientSummary,
          same(clientSummary),
        );
      });
    });

    group('AuthenticationType', () {
      test('toJson produces correct string values', () {
        expect(AuthenticationType.loginPassword.toJson(), 'login_password');
        expect(AuthenticationType.token.toJson(), 'token');
        expect(AuthenticationType.unknown.toJson(), 'unknown');
      });
    });

    group('SanitizedIceServer', () {
      test('toJson includes URLs and boolean credential flags', () {
        final server = SanitizedIceServer(
          urls: ['turn:turn.example.com:3478'],
          hasUsername: true,
          hasCredential: true,
        );

        final json = server.toJson();

        expect(json['urls'], ['turn:turn.example.com:3478']);
        expect(json['hasUsername'], true);
        expect(json['hasCredential'], true);
      });

      test('handles null URLs', () {
        final server = SanitizedIceServer(
          hasUsername: false,
          hasCredential: false,
        );

        final json = server.toJson();

        expect(json.containsKey('urls'), isFalse);
        expect(json['hasUsername'], false);
        expect(json['hasCredential'], false);
      });
    });
  });
}
