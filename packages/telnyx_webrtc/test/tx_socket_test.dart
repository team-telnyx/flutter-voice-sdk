import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:telnyx_webrtc/tx_socket.dart';

import 'tx_socket_test.mocks.dart';

@GenerateMocks([TxSocket])
void main() {
  test('verify that connect calls without error', () {
    var txSocket = MockTxSocket();
    txSocket.connect();
    verify(txSocket.connect());
  });

  test('verify close calls socket close method without error', () {
    var txSocket = MockTxSocket();
    txSocket.close();
    verify(txSocket.close());
  });

  test('verify close calls socket send method without error', () {
    var txSocket = MockTxSocket();
    txSocket.send("any");
    verify(txSocket.send("any"));
  });
}
