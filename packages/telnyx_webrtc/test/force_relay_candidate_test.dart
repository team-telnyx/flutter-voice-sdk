import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

void main() {
  group('ForceRelayCandidate Tests', () {
    test('CredentialConfig should have forceRelayCandidate parameter', () {
      final config = CredentialConfig(
        sipUser: 'testuser',
        sipPassword: 'testpass',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        logLevel: LogLevel.debug,
        debug: false,
        forceRelayCandidate: true,
      );

      expect(config.forceRelayCandidate, true);
    });

    test('CredentialConfig should default forceRelayCandidate to false', () {
      final config = CredentialConfig(
        sipUser: 'testuser',
        sipPassword: 'testpass',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        logLevel: LogLevel.debug,
        debug: false,
      );

      expect(config.forceRelayCandidate, false);
    });

    test('TokenConfig should have forceRelayCandidate parameter', () {
      final config = TokenConfig(
        sipToken: 'testtoken',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        forceRelayCandidate: true,
        logLevel: LogLevel.debug,
        debug: false,
      );

      expect(config.forceRelayCandidate, true);
    });

    test('TokenConfig should default forceRelayCandidate to false', () {
      final config = TokenConfig(
        sipToken: 'testtoken',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        logLevel: LogLevel.debug,
        debug: false,
      );

      expect(config.forceRelayCandidate, false);
    });

    test('TelnyxClient should return false when no config is set', () {
      final client = TelnyxClient();
      expect(client.getForceRelayCandidate(), false);
    });
  });
}
