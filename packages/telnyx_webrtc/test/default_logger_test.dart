import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/utils/logging/default_logger.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

void main() {
  group('DefaultLogger LogLevel Priority Tests', () {
    test('LogLevel enum should have correct priority values', () {
      expect(LogLevel.none.priority, 8);
      expect(LogLevel.error.priority, 6);
      expect(LogLevel.warning.priority, 5);
      expect(LogLevel.debug.priority, 3);
      expect(LogLevel.info.priority, 4);
      expect(LogLevel.verto.priority, 9);
      expect(LogLevel.all.priority, null);
    });

    test('LogLevel enum should have correct index values', () {
      expect(LogLevel.none.index, 0);
      expect(LogLevel.error.index, 1);
      expect(LogLevel.warning.index, 2);
      expect(LogLevel.debug.index, 3);
      expect(LogLevel.info.index, 4);
      expect(LogLevel.verto.index, 5);
      expect(LogLevel.all.index, 6);
    });

    test('Priority-based logging should work correctly', () {
      // Test the priority comparison logic that should be used
      // Higher priority numbers mean more restrictive (less verbose)

      // debug(3) should show: debug(3), info(4), warning(5), error(6), verto(9)
      expect(LogLevel.debug.priority! <= LogLevel.debug.priority!, true);
      expect(LogLevel.debug.priority! <= LogLevel.info.priority!, true);
      expect(LogLevel.debug.priority! <= LogLevel.warning.priority!, true);
      expect(LogLevel.debug.priority! <= LogLevel.error.priority!, true);
      expect(LogLevel.debug.priority! <= LogLevel.verto.priority!, true);

      // info(4) should show: info(4), warning(5), error(6), verto(9)
      expect(LogLevel.info.priority! <= LogLevel.debug.priority!, false);
      expect(LogLevel.info.priority! <= LogLevel.info.priority!, true);
      expect(LogLevel.info.priority! <= LogLevel.warning.priority!, true);
      expect(LogLevel.info.priority! <= LogLevel.error.priority!, true);
      expect(LogLevel.info.priority! <= LogLevel.verto.priority!, true);

      // error(6) should show: error(6), verto(9)
      expect(LogLevel.error.priority! <= LogLevel.debug.priority!, false);
      expect(LogLevel.error.priority! <= LogLevel.info.priority!, false);
      expect(LogLevel.error.priority! <= LogLevel.warning.priority!, false);
      expect(LogLevel.error.priority! <= LogLevel.error.priority!, true);
      expect(LogLevel.error.priority! <= LogLevel.verto.priority!, true);
    });
  });
}
