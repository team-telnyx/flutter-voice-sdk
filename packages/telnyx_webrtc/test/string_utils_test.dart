import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/utils/string_utils.dart';

void main() {
  group('String Utils', () {
    group('randomBetween', () {
      test('should generate number within range', () {
        for (int i = 0; i < 100; i++) {
          final result = randomBetween(1, 10);
          expect(result, greaterThanOrEqualTo(1));
          expect(result, lessThanOrEqualTo(10));
        }
      });

      test('should handle same from and to values', () {
        final result = randomBetween(5, 5);
        expect(result, equals(5));
      });

      test('should throw exception when from > to', () {
        expect(() => randomBetween(10, 5), throwsException);
      });

      test('should handle negative ranges', () {
        for (int i = 0; i < 50; i++) {
          final result = randomBetween(-10, -1);
          expect(result, greaterThanOrEqualTo(-10));
          expect(result, lessThanOrEqualTo(-1));
        }
      });

      test('should handle zero in range', () {
        for (int i = 0; i < 50; i++) {
          final result = randomBetween(-5, 5);
          expect(result, greaterThanOrEqualTo(-5));
          expect(result, lessThanOrEqualTo(5));
        }
      });
    });

    group('randomString', () {
      test('should generate string of correct length', () {
        expect(randomString(0), hasLength(0));
        expect(randomString(1), hasLength(1));
        expect(randomString(5), hasLength(5));
        expect(randomString(10), hasLength(10));
        expect(randomString(100), hasLength(100));
      });

      test('should generate different strings on multiple calls', () {
        final strings = <String>{};
        for (int i = 0; i < 50; i++) {
          strings.add(randomString(10));
        }
        // With high probability, we should get many different strings
        expect(strings.length, greaterThan(40));
      });

      test('should respect custom character range', () {
        // Generate string with only digits (ASCII 48-57)
        final numericString = randomString(10, from: 48, to: 57);
        expect(numericString, hasLength(10));
        for (int i = 0; i < numericString.length; i++) {
          final charCode = numericString.codeUnitAt(i);
          expect(charCode, greaterThanOrEqualTo(48));
          expect(charCode, lessThanOrEqualTo(57));
        }
      });

      test('should handle single character range', () {
        final singleCharString = randomString(5, from: 65, to: 65); // Only 'A'
        expect(singleCharString, equals('AAAAA'));
      });

      test('should use default ASCII printable range', () {
        final defaultString = randomString(10);
        expect(defaultString, hasLength(10));
        for (int i = 0; i < defaultString.length; i++) {
          final charCode = defaultString.codeUnitAt(i);
          expect(charCode, greaterThanOrEqualTo(33));
          expect(charCode, lessThanOrEqualTo(126));
        }
      });
    });

    group('randomNumeric', () {
      test('should generate numeric string of correct length', () {
        expect(randomNumeric(0), hasLength(0));
        expect(randomNumeric(1), hasLength(1));
        expect(randomNumeric(5), hasLength(5));
        expect(randomNumeric(10), hasLength(10));
      });

      test('should generate only numeric characters', () {
        final numericString = randomNumeric(20);
        expect(numericString, hasLength(20));

        final numericRegex = RegExp(r'^\d+$');
        expect(numericRegex.hasMatch(numericString), isTrue);

        // Check each character is a digit
        for (int i = 0; i < numericString.length; i++) {
          final char = numericString[i];
          expect(int.tryParse(char), isNotNull);
          expect(int.parse(char), greaterThanOrEqualTo(0));
          expect(int.parse(char), lessThanOrEqualTo(9));
        }
      });

      test('should generate different numeric strings on multiple calls', () {
        final strings = <String>{};
        for (int i = 0; i < 50; i++) {
          strings.add(randomNumeric(8));
        }
        // With high probability, we should get many different strings
        expect(strings.length, greaterThan(40));
      });

      test('should handle edge cases', () {
        expect(randomNumeric(0), equals(''));

        final singleDigit = randomNumeric(1);
        expect(singleDigit, hasLength(1));
        expect(int.tryParse(singleDigit), isNotNull);
      });

      test('should be usable for generating IDs', () {
        final id1 = randomNumeric(10);
        final id2 = randomNumeric(10);

        expect(id1, hasLength(10));
        expect(id2, hasLength(10));
        expect(id1, isNot(equals(id2))); // Very unlikely to be the same

        // Both should be valid numbers
        expect(int.tryParse(id1), isNotNull);
        expect(int.tryParse(id2), isNotNull);
      });
    });

    group('Integration tests', () {
      test('should work together for complex scenarios', () {
        // Generate a mixed string with letters and numbers
        final letters = randomString(5, from: 65, to: 90); // A-Z
        final numbers = randomNumeric(5);
        final combined = letters + numbers;

        expect(combined, hasLength(10));
        expect(letters, hasLength(5));
        expect(numbers, hasLength(5));

        // Verify letters part
        for (int i = 0; i < 5; i++) {
          final charCode = letters.codeUnitAt(i);
          expect(charCode, greaterThanOrEqualTo(65));
          expect(charCode, lessThanOrEqualTo(90));
        }

        // Verify numbers part
        final numericRegex = RegExp(r'^\d+$');
        expect(numericRegex.hasMatch(numbers), isTrue);
      });
    });
  });
}
