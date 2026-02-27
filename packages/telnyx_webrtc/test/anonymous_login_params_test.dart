import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/verto/send/anonymous_login_message.dart';

void main() {
  group('AnonymousLoginParams', () {
    test('should create AnonymousLoginParams with required parameters', () {
      final params = AnonymousLoginParams(
        targetType: 'ai_assistant',
        targetId: 'assistant-123',
      );

      expect(params.targetType, equals('ai_assistant'));
      expect(params.targetId, equals('assistant-123'));
      expect(params.targetVersionId, isNull);
      expect(params.conversationId, isNull);
      expect(params.userVariables, isNull);
      expect(params.reconnection, isNull);
      expect(params.userAgent, isNull);
      expect(params.sessionId, isNull);
    });

    test('should create AnonymousLoginParams with conversationId', () {
      final params = AnonymousLoginParams(
        targetType: 'ai_assistant',
        targetId: 'assistant-123',
        conversationId: 'conv-456',
      );

      expect(params.targetType, equals('ai_assistant'));
      expect(params.targetId, equals('assistant-123'));
      expect(params.conversationId, equals('conv-456'));
    });

    test('should create AnonymousLoginParams with all optional parameters', () {
      final userAgent = UserAgent(sdkVersion: '1.0.0', data: 'test-agent');
      final params = AnonymousLoginParams(
        targetType: 'ai_assistant',
        targetId: 'assistant-123',
        targetVersionId: 'v1',
        conversationId: 'conv-456',
        userVariables: {'key': 'value'},
        reconnection: true,
        userAgent: userAgent,
        sessionId: 'session-789',
      );

      expect(params.targetType, equals('ai_assistant'));
      expect(params.targetId, equals('assistant-123'));
      expect(params.targetVersionId, equals('v1'));
      expect(params.conversationId, equals('conv-456'));
      expect(params.userVariables, equals({'key': 'value'}));
      expect(params.reconnection, isTrue);
      expect(params.userAgent, equals(userAgent));
      expect(params.sessionId, equals('session-789'));
    });

    test('toJson should include conversationId when provided', () {
      final params = AnonymousLoginParams(
        targetType: 'ai_assistant',
        targetId: 'assistant-123',
        conversationId: 'conv-456',
        reconnection: false,
      );

      final json = params.toJson();

      expect(json['target_type'], equals('ai_assistant'));
      expect(json['target_id'], equals('assistant-123'));
      expect(json['conversation_id'], equals('conv-456'));
      expect(json['reconnection'], isFalse);
    });

    test('toJson should not include conversationId when null', () {
      final params = AnonymousLoginParams(
        targetType: 'ai_assistant',
        targetId: 'assistant-123',
        reconnection: false,
      );

      final json = params.toJson();

      expect(json['target_type'], equals('ai_assistant'));
      expect(json['target_id'], equals('assistant-123'));
      expect(json.containsKey('conversation_id'), isFalse);
      expect(json['reconnection'], isFalse);
    });

    test('fromJson should parse conversationId correctly', () {
      final json = {
        'target_type': 'ai_assistant',
        'target_id': 'assistant-123',
        'conversation_id': 'conv-456',
        'reconnection': true,
      };

      final params = AnonymousLoginParams.fromJson(json);

      expect(params.targetType, equals('ai_assistant'));
      expect(params.targetId, equals('assistant-123'));
      expect(params.conversationId, equals('conv-456'));
      expect(params.reconnection, isTrue);
    });

    test('fromJson should handle missing conversationId', () {
      final json = {
        'target_type': 'ai_assistant',
        'target_id': 'assistant-123',
        'reconnection': false,
      };

      final params = AnonymousLoginParams.fromJson(json);

      expect(params.targetType, equals('ai_assistant'));
      expect(params.targetId, equals('assistant-123'));
      expect(params.conversationId, isNull);
      expect(params.reconnection, isFalse);
    });
  });

  group('AnonymousLoginMessage', () {
    test('should create AnonymousLoginMessage with conversationId in params',
        () {
      final params = AnonymousLoginParams(
        targetType: 'ai_assistant',
        targetId: 'assistant-123',
        conversationId: 'conv-456',
        reconnection: false,
      );

      final message = AnonymousLoginMessage(
        id: 'msg-123',
        jsonrpc: '2.0',
        method: 'anonymous_login',
        params: params,
      );

      expect(message.id, equals('msg-123'));
      expect(message.jsonrpc, equals('2.0'));
      expect(message.method, equals('anonymous_login'));
      expect(message.params?.conversationId, equals('conv-456'));
    });

    test('toJson should include conversationId in params', () {
      final params = AnonymousLoginParams(
        targetType: 'ai_assistant',
        targetId: 'assistant-123',
        conversationId: 'conv-456',
        reconnection: false,
      );

      final message = AnonymousLoginMessage(
        id: 'msg-123',
        jsonrpc: '2.0',
        method: 'anonymous_login',
        params: params,
      );

      final json = message.toJson();

      expect(json['id'], equals('msg-123'));
      expect(json['jsonrpc'], equals('2.0'));
      expect(json['method'], equals('anonymous_login'));
      expect(json['params']['conversation_id'], equals('conv-456'));
    });
  });

  group('UserAgent', () {
    test('should create UserAgent with parameters', () {
      final userAgent = UserAgent(sdkVersion: '1.0.0', data: 'test-agent');

      expect(userAgent.sdkVersion, equals('1.0.0'));
      expect(userAgent.data, equals('test-agent'));
    });

    test('toJson should serialize correctly', () {
      final userAgent = UserAgent(sdkVersion: '1.0.0', data: 'test-agent');
      final json = userAgent.toJson();

      expect(json['sdkVersion'], equals('1.0.0'));
      expect(json['data'], equals('test-agent'));
    });

    test('fromJson should deserialize correctly', () {
      final json = {'sdkVersion': '1.0.0', 'data': 'test-agent'};
      final userAgent = UserAgent.fromJson(json);

      expect(userAgent.sdkVersion, equals('1.0.0'));
      expect(userAgent.data, equals('test-agent'));
    });
  });
}
