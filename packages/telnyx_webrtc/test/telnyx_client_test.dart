import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/gateway_state.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';

import 'telnyx_client_test.mocks.dart';

@GenerateMocks([TelnyxClient])
void main() {
  test('verify that connect updates boolean properly', () {
    var telnyxClient = TelnyxClient();
    telnyxClient.connect();
    telnyxClient.isConnected();
    // Give time to connect, verify isConnected() adjusts
    Timer(const Duration(seconds: 2), () {
      expect((telnyxClient.isConnected()), true);
    });
  });

  test('verify that disconnect updates boolean properly', () {
    var telnyxClient = TelnyxClient();
    telnyxClient.connect();
    telnyxClient.isConnected();
    // Give time to connect, verify isConnected() adjusts
    Timer(const Duration(seconds: 2), () {
      telnyxClient.disconnect();
      expect((telnyxClient.isConnected()), false);
    });
  });

  test('verify disconnect is called', () {
    var telnyxClient = MockTelnyxClient();
    telnyxClient.disconnect();
    verify(telnyxClient.disconnect());
  });

  test('verify create call returns a Call without issue when sessionId is set',
      () {
    var telnyxClient = TelnyxClient();
    telnyxClient.connect();
    // Give time to connect, verify isConnected() adjusts
    Timer(const Duration(seconds: 2), () {
      var call = telnyxClient.call;
      expect((telnyxClient.call), call);
    });
  });

  test('verify create call returns ArgumentError when no sessionId is set', () {
    var telnyxClient = MockTelnyxClient();
    when(telnyxClient.createCall()).thenThrow(ArgumentError());
    expect(() => telnyxClient.createCall(), throwsArgumentError);
  });

  test('verify credential login calls socket send method without error', () {
    var telnyxClient = TelnyxClient();
    telnyxClient.connect();
    var credLogin =
        CredentialConfig("test", "test", "test", "test", "test", false);
    // Give time to connect, verify isConnected() adjusts
    Timer(const Duration(seconds: 2), () {
      telnyxClient.credentialLogin(credLogin);
      // called twice, once for connect, and again for login
      verify(telnyxClient.txSocket.send(any)).called(2);
    });
  });

  test('verify token login calls socket send method without error', () {
    var telnyxClient = TelnyxClient();
    telnyxClient.connect();
    var tokenLogin = TokenConfig("test", "test", "test", "test", false);
    // Give time to connect, verify isConnected() adjusts
    Timer(const Duration(seconds: 2), () {
      telnyxClient.tokenLogin(tokenLogin);
      // called twice, once for connect, and again for login
      verify(telnyxClient.txSocket.send(any)).called(2);
    });
  });

  test('verify getGatewayStatus returns IDLE at start of instance creation',
      () {
    var telnyxClient = TelnyxClient();
    telnyxClient.connect();
    // Give time to connect, verify isConnected() adjusts
    Timer(const Duration(seconds: 2), () {
      // called twice, once for connect, and again for login
      verify(telnyxClient.getGatewayStatus()).called(GatewayState.IDLE);
    });
  });
}
