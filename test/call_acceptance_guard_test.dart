import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_flutter_webrtc/utils/call_acceptance_guard.dart';

void main() {
  group('CallAcceptanceGuard', () {
    test('allows only the first claim for one call', () {
      final guard = CallAcceptanceGuard();

      expect(guard.tryClaim('call-1'), isTrue);
      expect(guard.tryClaim('call-1'), isFalse);
      expect(guard.claimedCallId, 'call-1');
    });

    test('rejects a different call while one call owns the active slot', () {
      final guard = CallAcceptanceGuard();

      expect(guard.tryClaim('call-1'), isTrue);
      expect(guard.tryClaim('call-2'), isFalse);
      expect(guard.claimedCallId, 'call-1');
    });

    test('normalizes whitespace before deduplicating', () {
      final guard = CallAcceptanceGuard();

      expect(guard.tryClaim('  call-1  '), isTrue);
      expect(guard.tryClaim('call-1'), isFalse);
    });

    test('rejects missing call identifiers', () {
      final guard = CallAcceptanceGuard();

      expect(guard.tryClaim(null), isFalse);
      expect(guard.tryClaim(''), isFalse);
      expect(guard.tryClaim('   '), isFalse);
    });

    test('release permits retry after a failed acceptance', () {
      final guard = CallAcceptanceGuard();

      expect(guard.tryClaim('call-1'), isTrue);
      guard.release('call-1');
      expect(guard.tryClaim('call-1'), isTrue);
    });

    test('release of another call cannot clear the active slot', () {
      final guard = CallAcceptanceGuard();

      expect(guard.tryClaim('call-1'), isTrue);
      guard.release('call-2');
      expect(guard.tryClaim('call-2'), isFalse);
      expect(guard.claimedCallId, 'call-1');
    });

    test('reset permits a new call lifecycle', () {
      final guard = CallAcceptanceGuard();

      expect(guard.tryClaim('call-1'), isTrue);
      guard.reset();
      expect(guard.tryClaim('call-2'), isTrue);
    });
  });
}
