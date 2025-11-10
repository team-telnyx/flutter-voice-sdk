import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart';

// Generate mocks
@GenerateMocks([TxSocket, TelnyxClient])
import 'call_conversation_test.mocks.dart';

void main() {
  group('Call sendConversationMessage Tests', () {
    late MockTxSocket mockTxSocket;
    late MockTelnyxClient mockTxClient;
    late Call call;
    late CallHandler callHandler;

    setUp(() {
      mockTxSocket = MockTxSocket();
      mockTxClient = MockTelnyxClient();
      callHandler = CallHandler((state) {}, null);
      
      call = Call(
        mockTxSocket,
        mockTxClient,
        'test-session-id',
        'ringtone.wav',
        'ringback.wav',
        callHandler,
        () {},
        false,
      );
    });

    test('sendConversationMessage with text only should send correct message', () {
      // Arrange
      const message = 'Hello, assistant!';
      
      // Act
      call.sendConversationMessage(message);
      
      // Assert
      verify(mockTxSocket.send(any)).called(1);
      final capturedMessage = verify(mockTxSocket.send(captureAny)).captured.single;
      final decodedMessage = jsonDecode(capturedMessage);
      
      expect(decodedMessage['method'], equals('ai_conversation'));
      expect(decodedMessage['params']['type'], equals('conversation.item.create'));
      expect(decodedMessage['params']['item']['type'], equals('message'));
      expect(decodedMessage['params']['item']['role'], equals('user'));
      expect(decodedMessage['params']['item']['content'], hasLength(1));
      expect(decodedMessage['params']['item']['content'][0]['type'], equals('input_text'));
      expect(decodedMessage['params']['item']['content'][0]['text'], equals(message));
    });

    test('sendConversationMessage with single image (new parameter) should send correct message', () {
      // Arrange
      const message = 'What is in this image?';
      const base64Image = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD';
      
      // Act
      call.sendConversationMessage(message, base64Images: [base64Image]);
      
      // Assert
      verify(mockTxSocket.send(any)).called(1);
      final capturedMessage = verify(mockTxSocket.send(captureAny)).captured.single;
      final decodedMessage = jsonDecode(capturedMessage);
      
      expect(decodedMessage['params']['item']['content'], hasLength(2));
      expect(decodedMessage['params']['item']['content'][0]['type'], equals('input_text'));
      expect(decodedMessage['params']['item']['content'][0]['text'], equals(message));
      expect(decodedMessage['params']['item']['content'][1]['type'], equals('image_url'));
      expect(decodedMessage['params']['item']['content'][1]['image_url']['url'], equals(base64Image));
    });

    test('sendConversationMessage with multiple images should send correct message', () {
      // Arrange
      const message = 'Compare these images';
      const base64Images = [
        'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD',
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
        'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAE',
      ];
      
      // Act
      call.sendConversationMessage(message, base64Images: base64Images);
      
      // Assert
      verify(mockTxSocket.send(any)).called(1);
      final capturedMessage = verify(mockTxSocket.send(captureAny)).captured.single;
      final decodedMessage = jsonDecode(capturedMessage);
      
      expect(decodedMessage['params']['item']['content'], hasLength(4)); // 1 text + 3 images
      expect(decodedMessage['params']['item']['content'][0]['type'], equals('input_text'));
      expect(decodedMessage['params']['item']['content'][0]['text'], equals(message));
      
      for (int i = 0; i < base64Images.length; i++) {
        expect(decodedMessage['params']['item']['content'][i + 1]['type'], equals('image_url'));
        expect(decodedMessage['params']['item']['content'][i + 1]['image_url']['url'], equals(base64Images[i]));
      }
    });

    test('sendConversationMessage with deprecated base64Image parameter should work (backward compatibility)', () {
      // Arrange
      const message = 'What is in this image?';
      const base64Image = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD';
      
      // Act
      // ignore: deprecated_member_use_from_same_package
      call.sendConversationMessage(message, base64Image: base64Image);
      
      // Assert
      verify(mockTxSocket.send(any)).called(1);
      final capturedMessage = verify(mockTxSocket.send(captureAny)).captured.single;
      final decodedMessage = jsonDecode(capturedMessage);
      
      expect(decodedMessage['params']['item']['content'], hasLength(2));
      expect(decodedMessage['params']['item']['content'][0]['type'], equals('input_text'));
      expect(decodedMessage['params']['item']['content'][0]['text'], equals(message));
      expect(decodedMessage['params']['item']['content'][1]['type'], equals('image_url'));
      expect(decodedMessage['params']['item']['content'][1]['image_url']['url'], equals(base64Image));
    });

    test('sendConversationMessage should prioritize base64Images over deprecated base64Image', () {
      // Arrange
      const message = 'Test priority';
      const newImage = 'data:image/jpeg;base64,NEW_IMAGE';
      const deprecatedImage = 'data:image/jpeg;base64,DEPRECATED_IMAGE';
      
      // Act
      // ignore: deprecated_member_use_from_same_package
      call.sendConversationMessage(
        message, 
        base64Images: [newImage],
        base64Image: deprecatedImage,
      );
      
      // Assert
      verify(mockTxSocket.send(any)).called(1);
      final capturedMessage = verify(mockTxSocket.send(captureAny)).captured.single;
      final decodedMessage = jsonDecode(capturedMessage);
      
      expect(decodedMessage['params']['item']['content'], hasLength(2));
      expect(decodedMessage['params']['item']['content'][1]['image_url']['url'], equals(newImage));
    });

    test('sendConversationMessage should add data URL prefix if missing', () {
      // Arrange
      const message = 'Test image format';
      const rawBase64 = '/9j/4AAQSkZJRgABAQAAAQABAAD'; // Without data URL prefix
      
      // Act
      call.sendConversationMessage(message, base64Images: [rawBase64]);
      
      // Assert
      verify(mockTxSocket.send(any)).called(1);
      final capturedMessage = verify(mockTxSocket.send(captureAny)).captured.single;
      final decodedMessage = jsonDecode(capturedMessage);
      
      expect(decodedMessage['params']['item']['content'][1]['image_url']['url'], 
             equals('data:image/jpeg;base64,$rawBase64'));
    });

    test('sendConversationMessage with empty message should only send images', () {
      // Arrange
      const message = '';
      const base64Image = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD';
      
      // Act
      call.sendConversationMessage(message, base64Images: [base64Image]);
      
      // Assert
      verify(mockTxSocket.send(any)).called(1);
      final capturedMessage = verify(mockTxSocket.send(captureAny)).captured.single;
      final decodedMessage = jsonDecode(capturedMessage);
      
      expect(decodedMessage['params']['item']['content'], hasLength(1)); // Only image, no text
      expect(decodedMessage['params']['item']['content'][0]['type'], equals('image_url'));
      expect(decodedMessage['params']['item']['content'][0]['image_url']['url'], equals(base64Image));
    });

    test('sendConversationMessage should filter out empty images', () {
      // Arrange
      const message = 'Test filtering';
      const base64Images = [
        'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD',
        '', // Empty image should be filtered out
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
      ];
      
      // Act
      call.sendConversationMessage(message, base64Images: base64Images);
      
      // Assert
      verify(mockTxSocket.send(any)).called(1);
      final capturedMessage = verify(mockTxSocket.send(captureAny)).captured.single;
      final decodedMessage = jsonDecode(capturedMessage);
      
      expect(decodedMessage['params']['item']['content'], hasLength(3)); // 1 text + 2 images (empty filtered out)
      expect(decodedMessage['params']['item']['content'][0]['type'], equals('input_text'));
      expect(decodedMessage['params']['item']['content'][1]['type'], equals('image_url'));
      expect(decodedMessage['params']['item']['content'][2]['type'], equals('image_url'));
    });

    test('sendConversationMessage with null and empty base64Images should work', () {
      // Arrange
      const message = 'Just text';
      
      // Act - Test with null
      call.sendConversationMessage(message, base64Images: null);
      
      // Assert
      verify(mockTxSocket.send(any)).called(1);
      var capturedMessage = verify(mockTxSocket.send(captureAny)).captured.single;
      var decodedMessage = jsonDecode(capturedMessage);
      
      expect(decodedMessage['params']['item']['content'], hasLength(1)); // Only text
      expect(decodedMessage['params']['item']['content'][0]['type'], equals('input_text'));
      
      // Reset mock
      reset(mockTxSocket);
      
      // Act - Test with empty list
      call.sendConversationMessage(message, base64Images: []);
      
      // Assert
      verify(mockTxSocket.send(any)).called(1);
      capturedMessage = verify(mockTxSocket.send(captureAny)).captured.single;
      decodedMessage = jsonDecode(capturedMessage);
      
      expect(decodedMessage['params']['item']['content'], hasLength(1)); // Only text
      expect(decodedMessage['params']['item']['content'][0]['type'], equals('input_text'));
    });
  });
}