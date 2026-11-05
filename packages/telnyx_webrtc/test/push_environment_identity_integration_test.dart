import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

class RecordingSocket extends TxSocket {
  RecordingSocket() : super('wss://example.test');
  final messages = <Map<String, dynamic>>[];
  @override
  void connect() {}
  @override
  void close() {}
  @override
  void send(dynamic data) => messages.add(jsonDecode(data as String));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecordingSocket socket;
  late TelnyxClient client;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    socket = RecordingSocket();
    client = TelnyxClient(connectivityChanges: () => const Stream.empty())
      ..txSocket = socket;
  });
  tearDown(() {
    client.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  for (final tokenLogin in [false, true]) {
    final kind = tokenLogin ? 'token' : 'credential';
    final Config config = tokenLogin
        ? TokenConfig(
            sipToken: 'test-token',
            sipCallerIDName: 'test',
            sipCallerIDNumber: 'test',
            logLevel: LogLevel.none,
            debug: false,
            notificationToken: 'sandbox-token',
            pushNotificationEnvironment: 'development',
            mobileSdkName: 'wrapper',
            mobileSdkVersion: '1.0.0',
          )
        : CredentialConfig(
            sipUser: 'test-user',
            sipPassword: 'test-password',
            sipCallerIDName: 'test',
            sipCallerIDNumber: 'test',
            logLevel: LogLevel.none,
            debug: false,
            notificationToken: 'sandbox-token',
            pushNotificationEnvironment: 'development',
            mobileSdkName: 'wrapper',
            mobileSdkVersion: '1.0.0',
          );

    test('$kind push login and attach retain environment and SDK identity',
        () async {
      client.handlePushNotification(
        PushMetaData(callId: 'incoming', voiceSdkId: 'test-sdk-id'),
        config is CredentialConfig ? config : null,
        config is TokenConfig ? config : null,
      );
      socket.onOpen();
      await pumpEventQueue();
      final login = socket.messages.singleWhere((m) => m['method'] == 'login');
      final params = login['params'] as Map<String, dynamic>;
      expect(params['mobile_sdk_name'], 'wrapper');
      expect(params['mobile_sdk_version'], '1.0.0');
      expect(
        params['userVariables']['push_notification_environment'],
        'development',
      );
      expect(params['userVariables']['mobile_sdk_name'], 'wrapper');

      socket.onMessage(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 'registered',
          'result': {
            'params': {'state': 'REGED'},
          },
        }),
      );
      await pumpEventQueue();
      final attach = socket.messages
          .singleWhere((m) => m['method'] == 'telnyx_rtc.attachCalls');
      final attachParams = attach['params'] as Map<String, dynamic>;
      expect(attachParams['mobile_sdk_name'], 'wrapper');
      expect(attachParams['mobile_sdk_version'], '1.0.0');
      expect(
        attachParams['userVariables']['push_notification_environment'],
        'development',
      );
      expect(attachParams['userVariables']['mobile_sdk_name'], 'wrapper');
    });

    test('$kind region fallback retains environment and SDK identity', () {
      final copy = client.copyConfigWithAutoRegionForTest(config);
      expect(copy.pushNotificationEnvironment, 'development');
      expect(copy.effectiveSdkName, 'wrapper');
      expect(copy.effectiveSdkVersion, '1.0.0');
    });
  }
}
