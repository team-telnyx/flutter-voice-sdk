// ignore: avoid_web_libraries_in_flutter
import 'dart:html';
import 'package:logger/logger.dart';

typedef OnMessageCallback = void Function(dynamic msg);
typedef OnCloseCallback = void Function(int code, String reason);
typedef OnOpenCallback = void Function();

class TxSocket {
  TxSocket(this.hostAddress) {
    hostAddress = hostAddress.replaceAll('https:', 'wss:');
  }

  String hostAddress;
  final _logger = Logger();

  late WebSocket _socket;
  late OnOpenCallback onOpen;
  late OnMessageCallback onMessage;
  late OnCloseCallback onClose;

  connect() async {
    try {
      _socket = WebSocket(hostAddress);
      _socket.onOpen.listen((e) {
        onOpen.call();
      });

      _socket.onMessage.listen((e) {
        onMessage.call(e.data);
      });

      _socket.onClose.listen((e) {
        onClose.call(e.code ?? 0, e.reason ?? "Closed for unknown reason");
      });
    } catch (e) {
      onClose.call(500, e.toString());
    }
  }

  send(data) {
    if (_socket.readyState == WebSocket.OPEN) {
      _socket.send(data);
      _logger.i('TxSocket :: send : \n\n$data');
    } else {
      _logger.i('WebSocket not connected, message $data not sent');
    }
  }

  close() {
    _socket.close();
  }
}
