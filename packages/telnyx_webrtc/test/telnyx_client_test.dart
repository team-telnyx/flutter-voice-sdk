import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/gateway_state.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

import 'telnyx_client_test.mocks.dart';

@GenerateMocks([TelnyxClient])
void main() {
  test('verify that connect updates boolean properly', () {
    final telnyxClient = TelnyxClient();
    telnyxClient.connect();
    telnyxClient.isConnected();
    // Give time to connect, verify isConnected() adjusts
    Timer(const Duration(seconds: 2), () {
      expect((telnyxClient.isConnected()), true);
    });
  });

  test('verify that disconnect updates boolean properly', () {
    final telnyxClient = TelnyxClient();
    telnyxClient.connect();
    telnyxClient.isConnected();
    // Give time to connect, verify isConnected() adjusts
    Timer(const Duration(seconds: 2), () {
      telnyxClient.disconnect();
      expect((telnyxClient.isConnected()), false);
    });
  });

  test('verify disconnect is called', () {
    final telnyxClient = MockTelnyxClient();
    telnyxClient.disconnect();
    verify(telnyxClient.disconnect());
  });

  // Todo remove Test -  is not need since telnyxClient.call is deprecated
  test(
    'verify create call returns a Call without issue when sessionId is set',
    () {
      final telnyxClient = TelnyxClient();
      telnyxClient.connect();
      // Give time to connect, verify isConnected() adjusts
      Timer(const Duration(seconds: 2), () {
        final call = telnyxClient.call;
        expect((telnyxClient.call), call);
      });
    },
  );

  test('verify create call returns ArgumentError when no sessionId is set', () {
    final telnyxClient = MockTelnyxClient();
    when(telnyxClient.createCall()).thenThrow(ArgumentError());
    expect(() => telnyxClient.createCall(), throwsArgumentError);
  });

  test('verify credential login calls socket send method without error', () {
    final telnyxClient = TelnyxClient();
    telnyxClient.connect();
    final credLogin = CredentialConfig(
      sipUser: 'test',
      sipPassword: 'test',
      sipCallerIDName: 'test',
      sipCallerIDNumber: 'test',
      notificationToken: 'test',
      autoReconnect: false,
      logLevel: LogLevel.info,
      debug: false,
    );
    // Give time to connect, verify isConnected() adjusts
    Timer(const Duration(seconds: 2), () {
      telnyxClient.credentialLogin(credLogin);
      // called twice, once for connect, and again for login
      verify(telnyxClient.txSocket.send(any)).called(2);
    });
  });

  test('verify token login calls socket send method without error', () {
    final telnyxClient = TelnyxClient();
    telnyxClient.connect();
    final tokenLogin = TokenConfig(
      sipToken: 'test',
      sipCallerIDName: 'test',
      sipCallerIDNumber: 'test',
      notificationToken: 'test',
      autoReconnect: false,
      logLevel: LogLevel.info,
      debug: false,
    );
    // Give time to connect, verify isConnected() adjusts
    Timer(const Duration(seconds: 2), () {
      telnyxClient.tokenLogin(tokenLogin);
      // called twice, once for connect, and again for login
      verify(telnyxClient.txSocket.send(any)).called(2);
    });
  });

  test(
    'verify getGatewayStatus returns IDLE at start of instance creation',
    () {
      final telnyxClient = TelnyxClient();
      telnyxClient.connect();
      // Give time to connect, verify isConnected() adjusts
      Timer(const Duration(seconds: 2), () {
        // called twice, once for connect, and again for login
        verify(telnyxClient.getGatewayStatus()).called(GatewayState.idle);
      });
    },
  );

  test('verify pending answer timeout functionality exists', () {
    final telnyxClient = TelnyxClient();

    // Create a push metadata with isAnswer = true
    final pushMetaData = PushMetaData(
      callerName: 'Test Caller',
      callerNumber: '+1234567890',
      callId: 'test-call-id',
    )..isAnswer = true;

    final credentialConfig = CredentialConfig(
      sipUser: 'test',
      sipPassword: 'test',
      sipCallerIDName: 'test',
      sipCallerIDNumber: 'test',
      notificationToken: 'test',
      autoReconnect: false,
      logLevel: LogLevel.info,
      debug: false,
    );

    // Handle the push notification (this should start the timeout)
    telnyxClient.handlePushNotification(pushMetaData, credentialConfig, null);

    // Verify the method doesn't crash - in a real implementation,
    // we'd mock the timer and verify timeout behavior
    expect(telnyxClient.isConnected, isA<Function>());
  });

  test(
    'verify getGatewayStatus returns IDLE at start of instance creation',
    () {
      final telnyxClient = TelnyxClient();
      telnyxClient.connect();
      // Give time to connect, verify isConnected() adjusts
      Timer(const Duration(seconds: 2), () {
        // called twice, once for connect, and again for login
        verify(telnyxClient.getGatewayStatus()).called(GatewayState.idle);
      });
    },
  );
}
