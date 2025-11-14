import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/verto/send/conversation_message.dart';
import 'package:telnyx_webrtc/model/verto/receive/ai_conversation_message.dart';

void main() {
  group('ConversationMessage Tests', () {
    test('ConversationContentData should serialize text content correctly', () {
      final content = ConversationContentData(
        type: 'input_text',
        text: 'Hello, world!',
      );

      final json = content.toJson();
      expect(json['type'], equals('input_text'));
      expect(json['text'], equals('Hello, world!'));
      expect(json.containsKey('image_url'), isFalse);
    });

    test('ConversationContentData should serialize image content correctly',
        () {
      final imageUrl = ConversationImageUrl(
        url: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD',
      );
      final content = ConversationContentData(
        type: 'image_url',
        imageUrl: imageUrl,
      );

      final json = content.toJson();
      expect(json['type'], equals('image_url'));
      expect(json.containsKey('text'), isFalse);
      expect(json['image_url'], isNotNull);
      expect(json['image_url']['url'],
          equals('data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD'));
    });

    test('ConversationContentData should deserialize text content correctly',
        () {
      final json = {
        'type': 'input_text',
        'text': 'Hello, world!',
      };

      final content = ConversationContentData.fromJson(json);
      expect(content.type, equals('input_text'));
      expect(content.text, equals('Hello, world!'));
      expect(content.imageUrl, isNull);
    });

    test('ConversationContentData should deserialize image content correctly',
        () {
      final json = {
        'type': 'image_url',
        'image_url': {
          'url': 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD',
        },
      };

      final content = ConversationContentData.fromJson(json);
      expect(content.type, equals('image_url'));
      expect(content.text, isNull);
      expect(content.imageUrl, isNotNull);
      expect(content.imageUrl!.url,
          equals('data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD'));
    });

    test(
        'ConversationMessage should serialize complete message with text and image',
        () {
      final textContent = ConversationContentData(
        type: 'input_text',
        text: 'What is in this image?',
      );
      final imageContent = ConversationContentData(
        type: 'image_url',
        imageUrl: ConversationImageUrl(
          url: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD',
        ),
      );

      final item = ConversationItemData(
        id: '468f7607-4417-431c-8faf-8edb4ef03efb',
        type: 'message',
        role: 'user',
        content: [textContent, imageContent],
      );

      final params = ConversationMessageParams(
        type: 'conversation.item.create',
        previousItemId: null,
        item: item,
      );

      final message = ConversationMessage(
        id: '16931f6e-e359-4549-ac6f-56b4c5ad454f',
        jsonrpc: '2.0',
        method: 'ai_conversation',
        params: params,
      );

      final json = message.toJson();
      expect(json['id'], equals('16931f6e-e359-4549-ac6f-56b4c5ad454f'));
      expect(json['jsonrpc'], equals('2.0'));
      expect(json['method'], equals('ai_conversation'));
      expect(json['params']['type'], equals('conversation.item.create'));
      expect(json['params']['item']['content'], hasLength(2));
      expect(
          json['params']['item']['content'][0]['type'], equals('input_text'));
      expect(json['params']['item']['content'][1]['type'], equals('image_url'));
    });

    test('ConversationImageUrl should serialize and deserialize correctly', () {
      final imageUrl = ConversationImageUrl(
        url:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
      );

      final json = imageUrl.toJson();
      expect(
          json['url'],
          equals(
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=='));

      final deserialized = ConversationImageUrl.fromJson(json);
      expect(deserialized.url, equals(imageUrl.url));
    });
  });

  group('ConversationContent Receive Tests', () {
    test('ConversationContent should deserialize text content correctly', () {
      final json = {
        'type': 'text',
        'text': 'I can see an image in the conversation.',
      };

      final content = ConversationContent.fromJson(json);
      expect(content.type, equals('text'));
      expect(content.text, equals('I can see an image in the conversation.'));
      expect(content.imageUrl, isNull);
    });

    test('ConversationContent should deserialize image content correctly', () {
      final json = {
        'type': 'image_url',
        'image_url': {
          'url': 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD',
        },
      };

      final content = ConversationContent.fromJson(json);
      expect(content.type, equals('image_url'));
      expect(content.text, isNull);
      expect(content.imageUrl, isNotNull);
      expect(content.imageUrl!.url,
          equals('data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD'));
    });

    test('ConversationContent should serialize image content correctly', () {
      final content = ConversationContent(
        type: 'image_url',
        imageUrl: ConversationImageUrlReceive(
          url: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD',
        ),
      );

      final json = content.toJson();
      expect(json['type'], equals('image_url'));
      expect(json.containsKey('text'), isFalse);
      expect(json['image_url'], isNotNull);
      expect(json['image_url']['url'],
          equals('data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD'));
    });

    test(
        'ConversationImageUrlReceive should serialize and deserialize correctly',
        () {
      final imageUrl = ConversationImageUrlReceive(
        url:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
      );

      final json = imageUrl.toJson();
      expect(
          json['url'],
          equals(
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=='));

      final deserialized = ConversationImageUrlReceive.fromJson(json);
      expect(deserialized.url, equals(imageUrl.url));
    });
  });
}
