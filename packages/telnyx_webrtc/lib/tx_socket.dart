import 'dart:io';
import 'package:logger/logger.dart';

typedef OnMessageCallback = void Function(dynamic msg);
typedef OnCloseCallback = void Function(int code, String reason);
typedef OnOpenCallback = void Function();

class TxSocket {
  TxSocket(this.hostAddress);

  final String hostAddress;
  final _logger = Logger();

  late WebSocket _socket;
  late OnOpenCallback onOpen;
  late OnMessageCallback onMessage;
  late OnCloseCallback onClose;

  void connect() async {
    try {
      _socket = await WebSocket.connect(hostAddress);
      _socket.pingInterval = const Duration(seconds: 10);
      _socket.timeout(const Duration(seconds: 30));
      onOpen.call();
      _socket.listen((dynamic data) {
        onMessage.call(data);
      }, onDone: () {
        onClose.call(_socket.closeCode ?? 0,
            _socket.closeReason ?? "Closed for unknown reason");
      });
    } catch (e) {
      onClose.call(500, e.toString());
    }
  }

  void send(dynamic data) {
    _socket.add(data);
    _logger.i('TxSocket :: send : \n\n$data');
  }

  void close() {
    _socket.close();
  }
}
