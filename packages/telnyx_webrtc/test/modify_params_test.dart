import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/verto/send/modify_message_body.dart';

void main() {
  group('ModifyParams', () {
    test('should create ModifyParams with all fields', () {
      const action = 'updateMedia';
      const sessid = 'test-session-id';
      const sdp = 'v=0\r\no=- 123456789 123456789 IN IP4 127.0.0.1\r\n';
      const callID = 'test-call-id';

      final modifyParams = ModifyParams(
        action: action,
        sessid: sessid,
        sdp: sdp,
        callID: callID,
      );

      expect(modifyParams.action, equals(action));
      expect(modifyParams.sessid, equals(sessid));
      expect(modifyParams.sdp, equals(sdp));
      expect(modifyParams.callID, equals(callID));
    });

    test('should serialize to JSON correctly with all fields', () {
      const action = 'updateMedia';
      const sessid = 'test-session-id';
      const sdp = 'v=0\r\no=- 123456789 123456789 IN IP4 127.0.0.1\r\n';
      const callID = 'test-call-id';

      final modifyParams = ModifyParams(
        action: action,
        sessid: sessid,
        sdp: sdp,
        callID: callID,
      );

      final json = modifyParams.toJson();

      expect(json['action'], equals(action));
      expect(json['sessid'], equals(sessid));
      expect(json['sdp'], equals(sdp));
      expect(json['callID'], equals(callID));
    });

    test('should serialize to JSON correctly with null optional fields', () {
      const action = 'updateMedia';
      const sessid = 'test-session-id';

      final modifyParams = ModifyParams(
        action: action,
        sessid: sessid,
      );

      final json = modifyParams.toJson();

      expect(json['action'], equals(action));
      expect(json['sessid'], equals(sessid));
      expect(json.containsKey('sdp'), isFalse);
      expect(json.containsKey('callID'), isFalse);
    });

    test('should deserialize from JSON correctly', () {
      const action = 'updateMedia';
      const sessid = 'test-session-id';
      const sdp = 'v=0\r\no=- 123456789 123456789 IN IP4 127.0.0.1\r\n';
      const callID = 'test-call-id';

      final json = {
        'action': action,
        'sessid': sessid,
        'sdp': sdp,
        'callID': callID,
      };

      final modifyParams = ModifyParams.fromJson(json);

      expect(modifyParams.action, equals(action));
      expect(modifyParams.sessid, equals(sessid));
      expect(modifyParams.sdp, equals(sdp));
      expect(modifyParams.callID, equals(callID));
    });

    test('should deserialize from JSON correctly with missing optional fields', () {
      const action = 'updateMedia';
      const sessid = 'test-session-id';

      final json = {
        'action': action,
        'sessid': sessid,
      };

      final modifyParams = ModifyParams.fromJson(json);

      expect(modifyParams.action, equals(action));
      expect(modifyParams.sessid, equals(sessid));
      expect(modifyParams.sdp, isNull);
      expect(modifyParams.callID, isNull);
    });

    test('should handle updateMedia action specifically', () {
      const action = 'updateMedia';
      const callID = 'test-call-id';
      const sdp = 'v=0\r\no=- 123456789 123456789 IN IP4 127.0.0.1\r\n';

      final modifyParams = ModifyParams(
        action: action,
        callID: callID,
        sdp: sdp,
      );

      expect(modifyParams.action, equals('updateMedia'));
      expect(modifyParams.callID, isNotNull);
      expect(modifyParams.sdp, isNotNull);
    });
  });

  group('ModifyMessage', () {
    test('should create complete modify message for updateMedia', () {
      const id = 'test-message-id';
      const jsonrpc = '2.0';
      const method = 'telnyx_rtc.modify';

      final params = ModifyParams(
        action: 'updateMedia',
        callID: 'test-call-id',
        sdp: 'v=0\r\no=- 123456789 123456789 IN IP4 127.0.0.1\r\n',
      );

      final modifyMessage = ModifyMessage(
        id: id,
        jsonrpc: jsonrpc,
        method: method,
        params: params,
      );

      expect(modifyMessage.id, equals(id));
      expect(modifyMessage.jsonrpc, equals(jsonrpc));
      expect(modifyMessage.method, equals(method));
      expect(modifyMessage.params?.action, equals('updateMedia'));
    });

    test('should serialize complete modify message to JSON', () {
      const id = 'test-message-id';
      const jsonrpc = '2.0';
      const method = 'telnyx_rtc.modify';

      final params = ModifyParams(
        action: 'updateMedia',
        callID: 'test-call-id',
        sdp: 'v=0\r\no=- 123456789 123456789 IN IP4 127.0.0.1\r\n',
      );

      final modifyMessage = ModifyMessage(
        id: id,
        jsonrpc: jsonrpc,
        method: method,
        params: params,
      );

      final json = modifyMessage.toJson();

      expect(json['id'], equals(id));
      expect(json['jsonrpc'], equals(jsonrpc));
      expect(json['method'], equals(method));
      expect(json['params']['action'], equals('updateMedia'));
      expect(json['params']['callID'], equals('test-call-id'));
      expect(json['params']['sdp'], isNotNull);
    });
  });
}