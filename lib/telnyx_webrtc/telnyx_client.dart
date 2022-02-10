import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/call.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/receive/login_result_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/send/login_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/tx_socket.dart';
import 'package:uuid/uuid.dart';

typedef OnSocketMessageReceived = void Function(ReceivedMessage msg);

class TelnyxClient {
  late OnSocketMessageReceived onSocketMessageReceived;

  TxSocket txSocket = TxSocket("wss://rtc.telnyx.com:443");
  bool _closed = false;
  bool _connected = false;
  final logger = Logger();

  late String? sessionId;

  bool isConnected() {
    return _connected;
  }

  void connect(String providedHostAddress) {
    logger.i('connect()');
    if (isConnected()) {
      logger.i('WebSocket $providedHostAddress is already connected');
      return;
    }
    logger.i('connecting to WebSocket $providedHostAddress');
    try {
      txSocket.onOpen = () {
        _closed = false;
        _connected = true;
        logger.i('Web Socket is now connected');
        _onOpen();
      };

      txSocket.onMessage = (dynamic data) {
        _onMessage(data);
      };

      txSocket.onClose = (int closeCode, String closeReason) {
        logger.i('Closed [$closeCode, $closeReason]!');
        _connected = false;
        _onClose(true, closeCode, closeReason);
      };

      txSocket.connect(providedHostAddress);
    } catch (e, s) {
      logger.e(e.toString(), null, s);
      _connected = false;
      logger.e('WebSocket $providedHostAddress error: $e');
    }
  }

  Call createCall() {
    return Call(txSocket, this, sessionId);
  }

  void credentialLogin(CredentialConfig config) {
    var uuid = const Uuid();
    var user = config.sipUser;
    var password = config.sipPassword;
    //var fcmToken = config.fcmToken;

    var notificationParams = UserVariables(
        pushDeviceToken:
            "fJeOHNkMTO6_6b-C4tnlBU:APA91bGJHEVNDR5JHfX7JShwF0sRRgppfexzYvJgm1qZWK4Wm3xd5N0sId8sZ6LKUjsP8DDXabBLKTg_RLeWDOclqz0drx3c4d35TRdxP4eCzkh6kgKJIxJP495C6BuXWKTWqcSu3Gsp",
        pushNotificationProvider: "android");

    var loginParams = Params(
        login: user,
        passwd: password,
        loginParams: [],
        userVariables: notificationParams);
    var loginMessage = LoginMessage(
        id: uuid.toString(),
        method: "login",
        params: loginParams,
        jsonrpc: "2.0");

    String jsonLoginMessage = jsonEncode(loginMessage);

    txSocket.send(jsonLoginMessage);
  }

  void disconnect() {
    logger.i('disconnect()');
    if (_closed) return;
    // Don't wait for the WebSocket 'close' event, do it now.
    _closed = true;
    _connected = false;
    _onClose(true, 0, 'Client send disconnect');
    try {
      txSocket.close();
    } catch (error) {
      logger.e('close() | error closing the WebSocket: ' + error.toString());
    }
  }

  /// WebSocket Event Handlers
  void _onOpen() {
    logger.i('WebSocket connected');
  }

  void _onClose(bool wasClean, int code, String reason) {
    logger.i('WebSocket closed');
    if (wasClean == false) {
      logger.i('WebSocket abrupt disconnection');
    }
  }

  void _onMessage(dynamic data) {
    if (data != null) {
      if (data.toString().trim().isNotEmpty) {
        logger.i('Received WebSocket message :: ${data.toString().trim()}');

        /*
        //ToDo Handle incoming message logic
        if (data.toString().trim().contains("params")) {
          var paramJson = jsonEncode(data.toString());
          logger.i('Received WebSocket message - Contains Param :: $paramJson');
        }*/

        //Login success
        if (data.toString().trim().contains("result")) {
          var paramJson = jsonEncode(data.toString());
          logger
              .i('Received WebSocket message - Contains Result :: $paramJson');
          ResultMessage resultMessage =
              ResultMessage.fromJson(jsonDecode(data.toString()));
          sessionId = resultMessage.result?.sessid;
          logger.i('Client Session ID Set :: $sessionId');
        }

        //Login success
        if (data.toString().trim().contains("method")) {
          var paramJson = jsonEncode(data.toString());
          logger
              .i('Received WebSocket message - Contains Result :: $paramJson');
          ResultMessage resultMessage =
          ResultMessage.fromJson(jsonDecode(data.toString()));
          sessionId = resultMessage.result?.sessid;
          logger.i('Client Session ID Set :: $sessionId');
        }

        if (data.toString().trim().contains("state")) {
          ReceivedMessage stateMessage =
              ReceivedMessage.fromJson(jsonDecode(data.toString()));
          logger.i(
              'Received WebSocket message - Contains State  :: ${stateMessage.toString()}');
          if (stateMessage.stateParams?.state == "REGED") {
            logger.i('REGISTERED :: ${stateMessage.toString()}');
            onSocketMessageReceived.call(stateMessage);
          }
        }
      } else {
        logger.i('Received and ignored empty packet');
      }
    }
  }
}
