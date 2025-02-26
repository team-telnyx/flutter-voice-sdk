// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

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
  TxSocket(this.hostAddress) {
    hostAddress = hostAddress.replaceAll('https:', 'wss:');
  }

  String hostAddress;

  late WebSocket _socket;
  late OnOpenCallback onOpen;
  late OnMessageCallback onMessage;
  late OnCloseCallback onClose;

  /// Connect to the WebSocket server
  void connect() async {
    try {
      _socket = WebSocket(hostAddress);
      _socket.onOpen.listen((e) {
        onOpen.call();
      });

      _socket.onMessage.listen((e) {
        onMessage.call(e.data);
      });

      _socket.onClose.listen((e) {
        onClose.call(e.code ?? 0, e.reason ?? 'Closed for unknown reason');
      });
    } catch (e) {
      onClose.call(500, e.toString());
    }
  }

  /// Send data to the WebSocket server
  void send(data) {
    if (_socket.readyState == WebSocket.OPEN) {
      _socket.send(data);
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
