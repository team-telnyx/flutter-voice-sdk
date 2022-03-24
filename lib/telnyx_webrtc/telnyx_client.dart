import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/call.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/receive/incoming_invitation_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/receive/login_result_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/send/invite_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/send/login_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_flutter_webrtc/telnyx_webrtc/tx_socket_web.dart';
import 'package:uuid/uuid.dart';

typedef OnSocketMessageReceived = void Function(String method);

class TelnyxClient {
  late OnSocketMessageReceived onSocketMessageReceived;

  TxSocket txSocket = TxSocket("wss://rtc.telnyx.com:443");
  bool _closed = false;
  bool _connected = false;
  final logger = Logger();

  late String? sessionId;
  late IncomingInvitation currentInvite;

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
    return Call(txSocket, this, sessionId!);
  }

  IncomingInvitation getInvite() {
    return currentInvite;
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

    var loginParams = LoginParams(
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

        //Login success
        if (data.toString().trim().contains("result")) {
          var paramJson = jsonEncode(data.toString());
          logger
              .i('Received WebSocket message - Contains Result :: $paramJson');
          ResultMessage resultMessage =
              ResultMessage.fromJson(jsonDecode(data.toString()));
          sessionId = resultMessage.result?.sessid;
          logger.i('Client Session ID Set :: $sessionId');
        } else
        //Received Telnyx Method Message
        if (data.toString().trim().contains("method")) {
          var messageJson = jsonDecode(data.toString());
          logger.i(
              'Received WebSocket message - Contains Method :: $messageJson');
          switch (messageJson['method']) {
            case SocketMethod.CLIENT_READY:
              {
                ReceivedMessage clientReadyMessage =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                onSocketMessageReceived.call(SocketMethod.CLIENT_READY);
                break;
              }
            case SocketMethod.INVITE:
              {
                logger.i('INCOMING INVITATION :: $messageJson');
                IncomingInvitation invite =
                    IncomingInvitation.fromJson(jsonDecode(data.toString()));
                currentInvite = invite;
                onSocketMessageReceived.call(SocketMethod.INVITE);
                break;
              }
            case SocketMethod.ANSWER:
              {
                logger.i('INVITATION ANSWERED :: $messageJson');
                break;
              }
            case SocketMethod.BYE:
              {
                onSocketMessageReceived(SocketMethod.BYE);
                break;
              }
            case SocketMethod.GATEWAY_STATE:
              {
                ReceivedMessage stateMessage =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                logger.i(
                    'Received WebSocket message - Contains State  :: ${stateMessage.toString()}');
                if (stateMessage.stateParams?.state == "REGED") {
                  logger.i('REGISTERED :: ${stateMessage.toString()}');
                  onSocketMessageReceived.call(SocketMethod.GATEWAY_STATE);
                }
                break;
              }
          }
        }
      } else {
        logger.i('Received and ignored empty packet');
      }
    }
  }
}
