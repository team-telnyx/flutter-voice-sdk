import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/peer/trickle_ice_completion.dart';

void main() {
  group('TrickleIceCompletion', () {
    test('signals completion exactly once for the active call', () {
      final completion = TrickleIceCompletion()..begin('call-a');

      expect(completion.trySignal('call-a'), isTrue);
      expect(completion.trySignal('call-a'), isFalse);
    });

    test('ignores stale callbacks from another call', () {
      final completion = TrickleIceCompletion()..begin('call-b');

      expect(completion.trySignal('call-a'), isFalse);
      expect(completion.trySignal('call-b'), isTrue);
    });

    test('allows a new gathering cycle for the same call', () {
      final completion = TrickleIceCompletion()..begin('call-a');

      expect(completion.trySignal('call-a'), isTrue);

      completion.begin('call-a');

      expect(completion.trySignal('call-a'), isTrue);
    });

    test('reset ignores completion until gathering starts again', () {
      final completion = TrickleIceCompletion()
        ..begin('call-a')
        ..reset();

      expect(completion.trySignal('call-a'), isFalse);
    });
  });
}
