import 'package:test_api/src/backend/configuration/timeout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:telnyx_flutter_webrtc/main.dart';
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import '../helpers/test_config.dart';
import '../helpers/ui_helpers.dart';
import '../helpers/wait_helpers.dart';
import '../helpers/call_helpers.dart';

/// Connection tests - verify SDK can connect with different auth methods
void connectionTests() {
  patrolTest(
    'Connect with SIP credentials',
    timeout: Timeout(TestConfig.testTimeout),
    framePolicy: LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
    skip: !TestConfig.hasSipCredentials,
    ($) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = ignoreOverflowErrors;
      addTearDown(() => FlutterError.onError = originalOnError);

      // Launch app
      await $.pumpWidgetAndSettle(const MyApp());
      await $.grantPermissionsIfNeeded();

      // Login with SIP credentials
      await $.loginWithSipCredentials(
        profileName: 'SIP Test Profile',
      );

      // Verify we're connected and on home screen
      expect(find.byType(HomeScreen), findsOneWidget);

      // Verify connection status shows connected
      // (This requires the example app to have a status indicator with key)
      await $.waitForConnected();
    },
  );

  patrolTest(
    'Connect with Token',
    timeout: Timeout(TestConfig.testTimeout),
    framePolicy: LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
    skip: !TestConfig.hasTokenCredentials,
    ($) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = ignoreOverflowErrors;
      addTearDown(() => FlutterError.onError = originalOnError);

      // Launch app
      await $.pumpWidgetAndSettle(const MyApp());
      await $.grantPermissionsIfNeeded();

      // TODO: Implement token login flow
      // This requires the example app to support token-based login
      // await $.loginWithToken(TestConfig.tokenCredential);

      // For now, mark as pending
      markTestSkipped('Token login UI not implemented in example app');
    },
  );

  patrolTest(
    'Disconnect and reconnect',
    timeout: Timeout(TestConfig.testTimeout),
    framePolicy: LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
    skip: !TestConfig.hasSipCredentials,
    ($) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = ignoreOverflowErrors;
      addTearDown(() => FlutterError.onError = originalOnError);

      // Launch and connect
      await $.pumpWidgetAndSettle(const MyApp());
      await $.grantPermissionsIfNeeded();
      await $.loginWithSipCredentials();

      // Disconnect
      await $.tapTextIfExists('Disconnect');

      // Wait for disconnected state
      await $.waitForKeyWithText('connection_status', 'disconnected');

      // Reconnect
      await $.tapTextIfExists('Connect');

      // Wait for reconnection
      await $.waitForConnected();

      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );
}
