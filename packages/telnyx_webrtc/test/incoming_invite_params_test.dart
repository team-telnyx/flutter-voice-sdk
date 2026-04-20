import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';

void main() {
  group('IncomingInviteParams', () {
    group('fromJson', () {
      test('should parse telnyx_call_control_id when present', () {
        final json = {
          'callID': 'a2f31dd9-b9e6-403a-89d8-33767df14a56',
          'telnyx_call_control_id':
              'v3:mXnwxhjqOG0oDW6V6m7pEYGFCibIeNnsHQwvvUbqyADtTXKaX6uK4g',
          'telnyx_leg_id': '04461b14-1885-11f1-87f2-02420aefba1f',
          'telnyx_session_id': '044613a8-1885-11f1-87c4-02420aefba1f',
        };

        final params = IncomingInviteParams.fromJson(json);

        expect(params.callID, equals('a2f31dd9-b9e6-403a-89d8-33767df14a56'));
        expect(
          params.telnyxCallControlId,
          equals('v3:mXnwxhjqOG0oDW6V6m7pEYGFCibIeNnsHQwvvUbqyADtTXKaX6uK4g'),
        );
        expect(
          params.telnyxLegId,
          equals('04461b14-1885-11f1-87f2-02420aefba1f'),
        );
        expect(
          params.telnyxSessionId,
          equals('044613a8-1885-11f1-87c4-02420aefba1f'),
        );
      });

      test('should handle missing telnyx_call_control_id gracefully', () {
        final json = {
          'callID': 'test-call-id',
          'telnyx_leg_id': 'leg-id',
          'telnyx_session_id': 'session-id',
        };

        final params = IncomingInviteParams.fromJson(json);

        expect(params.callID, equals('test-call-id'));
        expect(params.telnyxCallControlId, isNull);
        expect(params.telnyxLegId, equals('leg-id'));
        expect(params.telnyxSessionId, equals('session-id'));
      });

      test('should parse all fields correctly from full answer event params',
          () {
        final json = {
          'callID': 'full-test-call-id',
          'sdp': 'v=0\r\no=- 123456 2 IN IP4 127.0.0.1\r\n',
          'caller_id_name': 'Test Caller',
          'caller_id_number': '+15551234567',
          'callee_id_name': 'Test Callee',
          'callee_id_number': '+15559876543',
          'telnyx_session_id': 'session-123',
          'telnyx_leg_id': 'leg-456',
          'telnyx_call_control_id': 'v3:control-id-789',
          'display_direction': 'outbound',
        };

        final params = IncomingInviteParams.fromJson(json);

        expect(params.callID, equals('full-test-call-id'));
        expect(params.sdp, equals('v=0\r\no=- 123456 2 IN IP4 127.0.0.1\r\n'));
        expect(params.callerIdName, equals('Test Caller'));
        expect(params.callerIdNumber, equals('+15551234567'));
        expect(params.calleeIdName, equals('Test Callee'));
        expect(params.calleeIdNumber, equals('+15559876543'));
        expect(params.telnyxSessionId, equals('session-123'));
        expect(params.telnyxLegId, equals('leg-456'));
        expect(params.telnyxCallControlId, equals('v3:control-id-789'));
        expect(params.displayDirection, equals('outbound'));
      });

      test('should handle empty JSON gracefully', () {
        final json = <String, dynamic>{};

        final params = IncomingInviteParams.fromJson(json);

        expect(params.callID, isNull);
        expect(params.telnyxCallControlId, isNull);
        expect(params.telnyxLegId, isNull);
        expect(params.telnyxSessionId, isNull);
      });
    });

    group('toJson', () {
      test('should serialize telnyx_call_control_id when present', () {
        final params = IncomingInviteParams(
          callID: 'test-call-id',
          telnyxCallControlId: 'v3:control-id-123',
          telnyxLegId: 'leg-id',
          telnyxSessionId: 'session-id',
        );

        final json = params.toJson();

        expect(json['callID'], equals('test-call-id'));
        expect(json['telnyx_call_control_id'], equals('v3:control-id-123'));
        expect(json['telnyx_leg_id'], equals('leg-id'));
        expect(json['telnyx_session_id'], equals('session-id'));
      });

      test('should serialize null telnyx_call_control_id', () {
        final params = IncomingInviteParams(
          callID: 'test-call-id',
          telnyxLegId: 'leg-id',
          telnyxSessionId: 'session-id',
        );

        final json = params.toJson();

        expect(json['callID'], equals('test-call-id'));
        expect(json['telnyx_call_control_id'], isNull);
        expect(json['telnyx_leg_id'], equals('leg-id'));
        expect(json['telnyx_session_id'], equals('session-id'));
      });

      test('should round-trip serialize/deserialize correctly', () {
        final originalParams = IncomingInviteParams(
          callID: 'round-trip-call-id',
          telnyxCallControlId: 'v3:round-trip-control-id',
          telnyxLegId: 'round-trip-leg-id',
          telnyxSessionId: 'round-trip-session-id',
          callerIdName: 'Round Trip Caller',
          callerIdNumber: '+15551112222',
        );

        final json = originalParams.toJson();
        final deserializedParams = IncomingInviteParams.fromJson(json);

        expect(deserializedParams.callID, equals(originalParams.callID));
        expect(
          deserializedParams.telnyxCallControlId,
          equals(originalParams.telnyxCallControlId),
        );
        expect(
          deserializedParams.telnyxLegId,
          equals(originalParams.telnyxLegId),
        );
        expect(
          deserializedParams.telnyxSessionId,
          equals(originalParams.telnyxSessionId),
        );
        expect(
          deserializedParams.callerIdName,
          equals(originalParams.callerIdName),
        );
        expect(
          deserializedParams.callerIdNumber,
          equals(originalParams.callerIdNumber),
        );
      });
    });

    group('constructor', () {
      test('should create instance with telnyxCallControlId', () {
        final params = IncomingInviteParams(
          callID: 'constructor-test-id',
          telnyxCallControlId: 'v3:constructor-control-id',
        );

        expect(params.callID, equals('constructor-test-id'));
        expect(params.telnyxCallControlId, equals('v3:constructor-control-id'));
      });

      test('should create instance without telnyxCallControlId', () {
        final params = IncomingInviteParams(
          callID: 'constructor-test-id',
        );

        expect(params.callID, equals('constructor-test-id'));
        expect(params.telnyxCallControlId, isNull);
      });
    });
  });
}
