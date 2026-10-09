import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/region.dart';
import 'package:telnyx_webrtc/model/tx_ice_server.dart';
import 'package:telnyx_webrtc/model/tx_server_configuration.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

void _expectCommonFieldsPreserved(Config source, Config copy) {
  expect(copy.sipCallerIDName, source.sipCallerIDName);
  expect(copy.sipCallerIDNumber, source.sipCallerIDNumber);
  expect(copy.notificationToken, source.notificationToken);
  expect(copy.autoReconnect, source.autoReconnect);
  expect(copy.logLevel, source.logLevel);
  expect(copy.debug, source.debug);
  expect(copy.customLogger, same(source.customLogger));
  expect(copy.ringTonePath, source.ringTonePath);
  expect(copy.ringbackPath, source.ringbackPath);
  expect(copy.reconnectionTimeout, source.reconnectionTimeout);
  expect(copy.pushAnswerTimeout, source.pushAnswerTimeout);
  expect(copy.region, Region.auto);
  expect(copy.fallbackOnRegionFailure, source.fallbackOnRegionFailure);
  expect(copy.forceRelayCandidate, source.forceRelayCandidate);
  expect(copy.iceServers, same(source.iceServers));
  expect(copy.serverConfiguration, same(source.serverConfiguration));
  expect(copy.callReportInterval, source.callReportInterval);
  expect(copy.callReportLogLevel, source.callReportLogLevel);
  expect(copy.callReportMaxLogEntries, source.callReportMaxLogEntries);
  expect(copy.enableCallReports, source.enableCallReports);
  expect(copy.debugOutput, source.debugOutput);
  expect(copy.debugLogLevel, source.debugLogLevel);
  expect(copy.debugLogMaxEntries, source.debugLogMaxEntries);
  expect(copy.callReportFlushInterval, source.callReportFlushInterval);
  expect(copy.prefetchIceCandidates, source.prefetchIceCandidates);
  expect(copy.autoRecoverCalls, source.autoRecoverCalls);
  expect(copy.hangupOnBeforeUnload, source.hangupOnBeforeUnload);
  expect(copy.maxReconnectAttempts, source.maxReconnectAttempts);
  expect(copy.enableStructuredErrors, source.enableStructuredErrors);
  expect(
    copy.enableSignalingHealthMonitor,
    source.enableSignalingHealthMonitor,
  );
  expect(
    copy.mediaPermissionsRecovery,
    same(source.mediaPermissionsRecovery),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  final iceServers = <TxIceServer>[
    const TxIceServer(
      urls: <String>['turn:example.test'],
      username: 'user',
      credential: 'credential',
    ),
  ];
  final serverConfiguration = TxServerConfiguration(
    host: 'rtc.example.test',
    port: 7443,
    webRTCIceServers: iceServers,
  );
  const mediaRecovery = MediaPermissionsRecoveryConfig(
    enabled: true,
    timeout: 12345,
  );

  group('VSDK-415 region fallback config copy', () {
    test('TokenConfig changes only region', () {
      final source = TokenConfig(
        sipToken: 'token',
        sipCallerIDName: 'caller',
        sipCallerIDNumber: 'number',
        notificationToken: 'notification',
        autoReconnect: false,
        logLevel: LogLevel.warning,
        debug: true,
        ringTonePath: 'ringtone',
        ringbackPath: 'ringback',
        reconnectionTimeout: 111,
        pushAnswerTimeout: 222,
        region: Region.eu,
        fallbackOnRegionFailure: true,
        forceRelayCandidate: true,
        iceServers: iceServers,
        serverConfiguration: serverConfiguration,
        callReportInterval: 333,
        callReportLogLevel: 'error',
        callReportMaxLogEntries: 444,
        enableCallReports: false,
        debugOutput: DebugOutput.file,
        debugLogLevel: DebugLogLevel.error,
        debugLogMaxEntries: 555,
        callReportFlushInterval: 666,
        prefetchIceCandidates: false,
        autoRecoverCalls: false,
        hangupOnBeforeUnload: false,
        maxReconnectAttempts: 7,
        enableStructuredErrors: false,
        enableSignalingHealthMonitor: false,
        mediaPermissionsRecovery: mediaRecovery,
      );
      final client =
          TelnyxClient(connectivityChanges: () => const Stream.empty());
      addTearDown(() async {
        client.dispose();
        await pumpEventQueue();
      });

      final copy = client.copyConfigWithAutoRegionForTest(source);

      expect(copy, isA<TokenConfig>());
      expect((copy as TokenConfig).sipToken, source.sipToken);
      _expectCommonFieldsPreserved(source, copy);
    });

    test('CredentialConfig changes only region', () {
      final source = CredentialConfig(
        sipUser: 'user',
        sipPassword: 'password',
        sipCallerIDName: 'caller',
        sipCallerIDNumber: 'number',
        notificationToken: 'notification',
        autoReconnect: false,
        logLevel: LogLevel.warning,
        debug: true,
        ringTonePath: 'ringtone',
        ringbackPath: 'ringback',
        reconnectionTimeout: 111,
        pushAnswerTimeout: 222,
        region: Region.apac,
        fallbackOnRegionFailure: true,
        forceRelayCandidate: true,
        iceServers: iceServers,
        serverConfiguration: serverConfiguration,
        callReportInterval: 333,
        callReportLogLevel: 'error',
        callReportMaxLogEntries: 444,
        enableCallReports: false,
        debugOutput: DebugOutput.file,
        debugLogLevel: DebugLogLevel.error,
        debugLogMaxEntries: 555,
        callReportFlushInterval: 666,
        prefetchIceCandidates: false,
        autoRecoverCalls: false,
        hangupOnBeforeUnload: false,
        maxReconnectAttempts: 7,
        enableStructuredErrors: false,
        enableSignalingHealthMonitor: false,
        mediaPermissionsRecovery: mediaRecovery,
      );
      final client =
          TelnyxClient(connectivityChanges: () => const Stream.empty());
      addTearDown(() async {
        client.dispose();
        await pumpEventQueue();
      });

      final copy = client.copyConfigWithAutoRegionForTest(source);

      expect(copy, isA<CredentialConfig>());
      expect((copy as CredentialConfig).sipUser, source.sipUser);
      expect(copy.sipPassword, source.sipPassword);
      _expectCommonFieldsPreserved(source, copy);
    });
  });
}
