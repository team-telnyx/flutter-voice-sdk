import 'dart:io';

import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

/// Message callback for when a message is received
typedef OnMessageCallback = void Function(dynamic msg);

/// Close callback for when the connection is closed
typedef OnCloseCallback = void Function(int code, String reason);

/// Open callback for when the connection is opened
typedef OnOpenCallback = void Function();

/// TxSocket class to handle the WebSocket connection
class TxSocket {
  /// Default constructor that initializes the host address and logger
  TxSocket(this.hostAddress);

  String hostAddress;

  late WebSocket _socket;
  late OnOpenCallback onOpen;
  late OnMessageCallback onMessage;
  late OnCloseCallback onClose;

  /// Connect to the WebSocket server
  void connect() async {
    try {
      GlobalLogger().i('TxSocket :: connect : $hostAddress');

      _socket = await WebSocket.connect(hostAddress);
      _socket
        ..pingInterval = const Duration(seconds: 10)
        ..timeout(const Duration(seconds: 30));
      onOpen.call();
      _socket.listen(
        (dynamic data) {
          onMessage.call(data);
        },
        onDone: () {
          onClose.call(
            _socket.closeCode ?? 0,
            _socket.closeReason ?? 'Closed for unknown reason',
          );
        },
      );
    } catch (e) {
      onClose.call(500, e.toString());
    }
  }

  /// Send data to the WebSocket server
  void send(dynamic data) {
    if (_socket.readyState == WebSocket.open) {
      _socket.add(data);
      GlobalLogger().i('TxSocket :: send : \n\n$data');
    } else {
      GlobalLogger().d('WebSocket not connected, message $data not sent');
    }
  }

  /// Close the WebSocket connection
  void close() {
    _socket.close();
  }
}
