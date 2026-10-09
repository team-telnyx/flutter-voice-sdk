import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_factory.dart';

void main() {
  group('VSDK-415: createTelnyxError factory', () {
    test('returns TelnyxError with correct fields from registry', () {
      final error = createTelnyxError(TelnyxErrorCodes.sdpCreateOfferFailed);

      expect(error.code, equals(40001));
      expect(error.name, equals('SDP_CREATE_OFFER_FAILED'));
      expect(error.message, isNotEmpty);
      expect(error.description, isNotEmpty);
      expect(error.causes, isNotEmpty);
      expect(error.solutions, isNotEmpty);
      expect(error.fatal, isTrue); // SDP errors are fatal
    });

    test('returns TelnyxError for media permission denied', () {
      final error =
          createTelnyxError(TelnyxErrorCodes.mediaMicrophonePermissionDenied);

      expect(error.code, equals(42001));
      expect(error.name, equals('MEDIA_MICROPHONE_PERMISSION_DENIED'));
      expect(error.fatal, isTrue);
    });

    test('returns TelnyxError for WebSocket error (non-fatal)', () {
      final error = createTelnyxError(TelnyxErrorCodes.webSocketError);

      expect(error.code, equals(45002));
      expect(error.name, equals('WEBSOCKET_ERROR'));
      expect(error.fatal, isFalse);
    });

    test('throws ArgumentError for unknown code', () {
      expect(
        () => createTelnyxError(99999),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('overrides message when provided', () {
      final error = createTelnyxError(
        TelnyxErrorCodes.sdpCreateOfferFailed,
        message: 'Custom error message',
      );

      expect(error.message, equals('Custom error message'));
    });

    test('uses registry default message when not overridden', () {
      final error = createTelnyxError(TelnyxErrorCodes.sdpCreateOfferFailed);

      // The message should match the registry entry, not be empty
      expect(error.message, isNotEmpty);
      expect(error.message, isNot(equals('')));
    });

    test('overrides fatal when provided', () {
      final error = createTelnyxError(
        TelnyxErrorCodes.sdpCreateOfferFailed,
        fatal: false,
      );

      // SDP_CREATE_OFFER_FAILED defaults to fatal: true, but we override
      expect(error.fatal, isFalse);
    });

    test('uses registry default fatal when not overridden', () {
      final error = createTelnyxError(TelnyxErrorCodes.holdFailed);

      // HOLD_FAILED defaults to fatal: false
      expect(error.fatal, isFalse);
    });

    test('wraps string originalError in Error', () {
      final error = createTelnyxError(
        TelnyxErrorCodes.unexpectedError,
        originalError: 'something went wrong',
      );

      expect(error.originalError, isNotNull);
    });

    test('preserves Exception as originalError', () {
      final original = Exception('inner failure');
      final error = createTelnyxError(
        TelnyxErrorCodes.unexpectedError,
        originalError: original,
      );

      expect(error.originalError, same(original));
    });

    test('originalError is null when not provided', () {
      final error = createTelnyxError(TelnyxErrorCodes.unexpectedError);

      expect(error.originalError, isNull);
    });

    test('returns a TelnyxError that implements Exception', () {
      final error = createTelnyxError(TelnyxErrorCodes.unexpectedError);

      expect(error, isA<TelnyxError>());
      expect(error, isA<Exception>());
    });
  });
}
