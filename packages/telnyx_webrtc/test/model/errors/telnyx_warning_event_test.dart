import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_event.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning.dart';

void main() {
  group('VSDK-396: TelnyxWarningEvent', () {
    const warning = TelnyxWarning(
      code: 33001,
      name: 'ICE_CONNECTIVITY_LOST',
      message: 'Connection interrupted',
      description: 'ICE connection transitioned to disconnected state.',
      causes: ['Temporary network interruption'],
      solutions: ['Wait for automatic recovery'],
    );

    test('constructs with warning and required sessionId', () {
      final event = TelnyxWarningEvent(
        warning: warning,
        sessionId: 'session-abc',
      );

      expect(event.warning, same(warning));
      expect(event.sessionId, equals('session-abc'));
      expect(event.reason, isNull);
      expect(event.source, isNull);
      expect(event.callId, isNull);
    });

    test('constructs with optional reason, source, and callId', () {
      final event = TelnyxWarningEvent(
        warning: warning,
        reason: 'Probe timed out',
        source: 'probe',
        sessionId: 'session-abc',
        callId: 'call-xyz',
      );

      expect(event.reason, equals('Probe timed out'));
      expect(event.source, equals('probe'));
      expect(event.callId, equals('call-xyz'));
    });

    test('source can be "probe"', () {
      final event = TelnyxWarningEvent(
        warning: warning,
        source: 'probe',
        sessionId: 's1',
      );

      expect(event.source, equals('probe'));
    });

    test('source can be "request"', () {
      final event = TelnyxWarningEvent(
        warning: warning,
        source: 'request',
        sessionId: 's1',
      );

      expect(event.source, equals('request'));
    });

    test('source can be "peer_failure"', () {
      final event = TelnyxWarningEvent(
        warning: warning,
        source: 'peer_failure',
        sessionId: 's1',
      );

      expect(event.source, equals('peer_failure'));
    });

    test('source can be "no_rtp"', () {
      final event = TelnyxWarningEvent(
        warning: warning,
        source: 'no_rtp',
        sessionId: 's1',
      );

      expect(event.source, equals('no_rtp'));
    });
  });
}
