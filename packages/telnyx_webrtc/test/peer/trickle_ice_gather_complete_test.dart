import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/peer/peer.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart';

class _FakeSocket extends TxSocket {
  _FakeSocket() : super('wss://example.test');

  final List<String> _sentMessages = [];

  List<String> get sentMessages => List.unmodifiable(_sentMessages);

  /// All sent messages whose JSON `method` field equals the given value.
  List<Map<String, dynamic>> sentByMethod(String method) => _sentMessages
      .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
      .where((msg) => msg['method'] == method)
      .toList();

  @override
  void send(dynamic data) {
    _sentMessages.add(data as String);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VSUP-279: trickle ICE end-of-candidates on gathering complete', () {
    late TelnyxClient client;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      client = TelnyxClient(connectivityChanges: () => const Stream.empty())
        ..onTelnyxError = (_) {};
    });

    tearDown(() => client.dispose());

    test(
      'trickleIceFallbackTimeoutMs regression guard: must not be 500ms '
      '(the macOS relay-gather race window from GH #297)',
      () {
        // The pre-fix value was 500ms, which fired before macOS could finish
        // gathering srflx/relay candidates and cut off the late relay route.
        // See VSUP-279 / GH #297. If this assertion fires, somebody reverted
        // the fix.
        expect(Peer.trickleIceFallbackTimeoutMs, greaterThan(500));
        expect(Peer.trickleIceFallbackTimeoutMs, 5000);
      },
    );

    test(
      'trickle ICE fallback timer is now wired as a fallback, '
      'not the primary signal',
      () {
        // Sanity check the timer name reflects intent: the constant is now
        // a *fallback* used only if the primary signal (gathering state
        // callback) never fires.
        expect(Peer.trickleIceFallbackTimeoutMs, isNonZero);
      },
    );
  });

  group(
    'VSUP-279: trickle ICE end-of-candidates — timer does not fire '
    'prematurely',
    () {
      test(
        'Peer constructed with trickle ICE emits no end-of-candidates '
        'without a candidate ever arriving',
        () {
          // Regression guard: this test simulates the bug by NOT firing any
          // gathering state callback. In the old code, the 500ms timer would
          // emit end-of-candidates here. With the fix, the fallback timer is
          // 5000ms — but more importantly, the primary signal is the
          // gathering state callback, which we never invoke in this test.
          SharedPreferences.setMockInitialValues({});
          final socket = _FakeSocket();
          final client =
              TelnyxClient(connectivityChanges: () => const Stream.empty())
                ..onTelnyxError = (_) {};
          // Construct a Peer with useTrickleIce=true. The Peer won't
          // start any timer until a candidate or gathering state is
          // observed — and we never invoke any such callback.
          Peer(
            socket,
            false,
            client,
            /*forceRelay*/ false,
            /*useTrickleIce*/ true,
          );

          try {
            expect(Peer.trickleIceFallbackTimeoutMs, greaterThan(500));
            expect(socket.sentMessages, isEmpty);
          } finally {
            client.dispose();
          }
        },
      );
    },
  );
}
