import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/errors/request_timeout_error.dart';

void main() {
  group('VSDK-396: RequestTimeoutError', () {
    test('stores requestId, timeoutMs, and method', () {
      final error = RequestTimeoutError('req-123', 10000, 'telnyx_rtc.modify');

      expect(error.requestId, equals('req-123'));
      expect(error.timeoutMs, equals(10000));
      expect(error.method, equals('telnyx_rtc.modify'));
    });

    test('method defaults to empty string', () {
      final error = RequestTimeoutError('req-456', 5000);

      expect(error.method, equals(''));
    });

    test('toString includes requestId, method, and timeout', () {
      final error = RequestTimeoutError('req-789', 10000, 'telnyx_rtc.ping');

      final str = error.toString();

      expect(str, contains('req-789'));
      expect(str, contains('telnyx_rtc.ping'));
      expect(str, contains('10000'));
    });

    test('toString uses "unknown" for method when empty', () {
      final error = RequestTimeoutError('req-000', 3000);

      final str = error.toString();

      expect(str, contains('unknown'));
    });

    test('implements Exception', () {
      final error = RequestTimeoutError('req-1', 5000);

      expect(error, isA<Exception>());
    });
  });

  group('VSDK-396: StaleRequestError', () {
    test('stores requestId, staleGeneration, and currentGeneration', () {
      final error = StaleRequestError('req-123', 2, 3);

      expect(error.requestId, equals('req-123'));
      expect(error.staleGeneration, equals(2));
      expect(error.currentGeneration, equals(3));
    });

    test('toString includes requestId, staleGeneration, and currentGeneration',
        () {
      final error = StaleRequestError('req-456', 1, 5);

      final str = error.toString();

      expect(str, contains('req-456'));
      expect(str, contains('gen=1'));
      expect(str, contains('current=5'));
    });

    test('implements Exception', () {
      final error = StaleRequestError('req-1', 0, 1);

      expect(error, isA<Exception>());
    });
  });
}
