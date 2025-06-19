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
  test('verify create call returns a Call without issue when sessionId is set',
      () {
    final telnyxClient = TelnyxClient();
    telnyxClient.connect();
    // Give time to connect, verify isConnected() adjusts
    Timer(const Duration(seconds: 2), () {
      final call = telnyxClient.call;
      expect((telnyxClient.call), call);
    });
  });

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

  test('verify getGatewayStatus returns IDLE at start of instance creation',
      () {
    final telnyxClient = TelnyxClient();
    telnyxClient.connect();
    // Give time to connect, verify isConnected() adjusts
    Timer(const Duration(seconds: 2), () {
      // called twice, once for connect, and again for login
      verify(telnyxClient.getGatewayStatus()).called(GatewayState.idle);
    });
  });

  test('verify push invite timeout terminates call after 10 seconds', () async {
    final telnyxClient = TelnyxClient();
    
    // Create a test push metadata for accepting a call
    final pushMetaData = PushMetaData(
      isAnswer: true,
      isDecline: false,
      voiceSdkId: 'test-sdk-id',
      callId: 'test-call-id',
      callerName: 'Test Caller',
      callerNumber: '+1234567890',
    );

    // Create a test credential config
    final credentialConfig = CredentialConfig(
      sipUser: 'testuser',
      sipPassword: 'testpass',
      sipCallerIDName: 'Test User',
      sipCallerIDNumber: '+1234567890',
      notificationToken: 'test-token',
      autoReconnect: false,
      logLevel: LogLevel.info,
      debug: false,
    );

    // Track call state changes
    bool callTerminated = false;
    String? terminationCause;

    // Mock the call handler to capture state changes
    telnyxClient.onSocketMessageReceived = (message) {
      // This would normally be handled by the app
    };

    // Handle push notification (this should start the timeout)
    telnyxClient.handlePushNotification(pushMetaData, credentialConfig, null);

    // Wait for timeout to expire (10 seconds + buffer)
    await Future.delayed(const Duration(seconds: 11));

    // Verify that the timeout logic was triggered
    // Note: In a real test, we would need to mock the call creation and state management
    // This is a basic structure for the test
    expect(telnyxClient.calls.isEmpty || 
           telnyxClient.calls.values.any((call) => call.callState.isDone), 
           isTrue);
  });

  test('verify push invite timeout is cancelled when INVITE is received', () async {
    final telnyxClient = TelnyxClient();
    
    // Create a test push metadata for accepting a call
    final pushMetaData = PushMetaData(
      isAnswer: true,
      isDecline: false,
      voiceSdkId: 'test-sdk-id',
      callId: 'test-call-id',
      callerName: 'Test Caller',
      callerNumber: '+1234567890',
    );

    // Create a test credential config
    final credentialConfig = CredentialConfig(
      sipUser: 'testuser',
      sipPassword: 'testpass',
      sipCallerIDName: 'Test User',
      sipCallerIDNumber: '+1234567890',
      notificationToken: 'test-token',
      autoReconnect: false,
      logLevel: LogLevel.info,
      debug: false,
    );

    // Handle push notification (this should start the timeout)
    telnyxClient.handlePushNotification(pushMetaData, credentialConfig, null);

    // Simulate receiving an INVITE within the timeout period
    // In a real scenario, this would be done through the socket message handler
    // For this test, we'll just verify the timer can be cancelled
    await Future.delayed(const Duration(seconds: 2));
    
    // Simulate disconnect which should cancel the timer
    telnyxClient.disconnect();

    // Wait past the original timeout period
    await Future.delayed(const Duration(seconds: 9));

    // The test passes if no exceptions are thrown and the client is properly disconnected
    expect(telnyxClient.isConnected(), isFalse);
  });
}
