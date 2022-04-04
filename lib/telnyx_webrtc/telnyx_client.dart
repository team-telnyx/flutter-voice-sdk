import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/call.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/gateway_state.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/receive/login_result_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/send/gateway_request_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/send/login_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/telnyx_message.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_flutter_webrtc/telnyx_webrtc/tx_socket_web.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

typedef OnSocketMessageReceived = void Function(TelnyxMessage message);

class TelnyxClient {
  late OnSocketMessageReceived onSocketMessageReceived;

  TxSocket txSocket = TxSocket("wss://rtc.telnyx.com:443");
  bool _closed = false;
  bool _connected = false;
  final logger = Logger();

  late String? sessionId;
  late ReceivedMessage currentInvite;
  late Call call;

  // Gateway registration variables
  static const int RETRY_REGISTER_TIME = 3;
  static const int RETRY_CONNECT_TIME = 3;
  static const int GATEWAY_RESPONSE_DELAY = 3000;

  late Timer _gatewayResponseTimer;
  bool _autoReconnectLogin = true;
  bool _waitingForReg = true;
  int _registrationRetryCounter = 0;
  int _connectRetryCounter = 0;
  String _gatewayState = GatewayState.IDLE;

  late String storedHostAddress;
  late CredentialConfig storedCredentialConfig;

  bool isConnected() {
    return _connected;
  }

  void connect(String providedHostAddress) {
    storedHostAddress = providedHostAddress;
    _invalidateGatewayResponseTimer();
    _resetGatewayCounters();
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

  void _reconnectToSocket() {
    txSocket.close();
    txSocket.connect(storedHostAddress);
    // Delay to allow connection
    Timer(const Duration(seconds: 1), () {
      credentialLogin(storedCredentialConfig);
    });
  }

  Call createCall() {
    call = Call(txSocket, sessionId!);
    return call;
  }

  ReceivedMessage getInvite() {
    return currentInvite;
  }

  void credentialLogin(CredentialConfig config) {
    storedCredentialConfig = config;
    var uuid = const Uuid();
    var user = config.sipUser;
    var password = config.sipPassword;
    var fcmToken = config.fcmToken;
    UserVariables? notificationParams;
    _autoReconnectLogin = config.autoReconnect ?? true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      notificationParams = UserVariables(
          pushDeviceToken: fcmToken, pushNotificationProvider: "android");
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      notificationParams = UserVariables(
          pushDeviceToken: fcmToken, pushNotificationProvider: "ios");
    }

    var loginParams = LoginParams(
        login: user,
        passwd: password,
        loginParams: [],
        userVariables: notificationParams);
    var loginMessage = LoginMessage(
        id: uuid.toString(),
        method: SocketMethod.LOGIN,
        params: loginParams,
        jsonrpc: "2.0");

    String jsonLoginMessage = jsonEncode(loginMessage);

    txSocket.send(jsonLoginMessage);
  }

  void disconnect() {
    _invalidateGatewayResponseTimer();
    _resetGatewayCounters();
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
                if (_gatewayState != GatewayState.REGED) {
                  logger.i('Retrieving Gateway state...');
                  if (_waitingForReg) {
                    _requestGatewayStatus();
                    _gatewayResponseTimer = Timer(
                        const Duration(milliseconds: GATEWAY_RESPONSE_DELAY),
                        () {
                      if (_registrationRetryCounter < RETRY_REGISTER_TIME) {
                        if (_waitingForReg) {
                          _onMessage(messageJson);
                        }
                        _registrationRetryCounter++;
                      } else {
                        logger.i('GATEWAY REGISTRATION TIMEOUT');
                      }
                    });
                  }
                } else {
                  ReceivedMessage clientReadyMessage =
                      ReceivedMessage.fromJson(jsonDecode(data.toString()));
                  var message = TelnyxMessage(
                      socketMethod: SocketMethod.CLIENT_READY,
                      message: clientReadyMessage);
                  onSocketMessageReceived.call(message);
                }
                break;
              }
            case SocketMethod.INVITE:
              {
                logger.i('INCOMING INVITATION :: $messageJson');
                ReceivedMessage invite =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                currentInvite = invite;
                var message = TelnyxMessage(
                    socketMethod: SocketMethod.INVITE, message: invite);
                onSocketMessageReceived.call(message);
                break;
              }
            case SocketMethod.ANSWER:
              {
                logger.i('INVITATION ANSWERED :: $messageJson');
                ReceivedMessage inviteAnswer =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                var message = TelnyxMessage(
                    socketMethod: SocketMethod.ANSWER, message: inviteAnswer);
                onSocketMessageReceived.call(message);
                break;
              }
            case SocketMethod.BYE:
              {
                logger.i('BYE RECEIVED :: $messageJson');
                ReceivedMessage bye =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                var message =
                    TelnyxMessage(socketMethod: SocketMethod.BYE, message: bye);
                onSocketMessageReceived(message);
                break;
              }
            case SocketMethod.GATEWAY_STATE:
              {
                ReceivedMessage stateMessage =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                var message = TelnyxMessage(
                    socketMethod: SocketMethod.GATEWAY_STATE,
                    message: stateMessage);
                logger.i(
                    'Received WebSocket message - Contains State  :: ${stateMessage.toString()}');
                switch (stateMessage.stateParams?.state) {
                  case GatewayState.REGED:
                    {
                      logger.i(
                          'GATEWAY REGISTERED :: ${stateMessage.toString()}');
                      _invalidateGatewayResponseTimer();
                      _gatewayState = GatewayState.REGED;
                      _waitingForReg = false;
                      onSocketMessageReceived.call(message);
                      break;
                    }
                  case GatewayState.NOREG:
                    {
                      logger.i(
                          'GATEWAY REGISTRATION TIMEOUT :: ${stateMessage.toString()}');
                      _gatewayState = GatewayState.NOREG;
                      _invalidateGatewayResponseTimer();
                      onSocketMessageReceived.call(message);
                      break;
                    }
                  case GatewayState.FAILED:
                    {
                      logger.i(
                          'GATEWAY REGISTRATION FAILED :: ${stateMessage.toString()}');
                      _gatewayState = GatewayState.FAILED;
                      _invalidateGatewayResponseTimer();
                      onSocketMessageReceived.call(message);
                      break;
                    }
                  case GatewayState.FAIL_WAIT:
                    {
                      logger.i(
                          'GATEWAY REGISTRATION FAILED :: Wait for Retry :: ${stateMessage.toString()}');
                      _gatewayState = GatewayState.FAIL_WAIT;
                      if (_autoReconnectLogin &&
                          _connectRetryCounter < RETRY_CONNECT_TIME) {
                        _connectRetryCounter++;
                        _reconnectToSocket();
                      } else {
                        _invalidateGatewayResponseTimer();
                        logger
                            .i('GATEWAY REGISTRATION FAILED AFTER REATTEMPTS');
                      }
                      break;
                    }
                  case GatewayState.EXPIRED:
                    {
                      logger.i(
                          'GATEWAY REGISTRATION TIMEOUT :: ${stateMessage.toString()}');
                      _gatewayState = GatewayState.EXPIRED;
                      _invalidateGatewayResponseTimer();
                      onSocketMessageReceived.call(message);
                      break;
                    }
                  default:
                    {
                      _invalidateGatewayResponseTimer();
                      logger.i('GATEWAY REGISTRATION FAILED');
                    }
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

  void _requestGatewayStatus() {
    if (_waitingForReg) {
      var uuid = const Uuid();
      var gatewayRequestParams = GatewayRequestStateParams();
      var gatewayRequestMessage = GatewayRequestMessage(
          id: uuid.toString(),
          method: SocketMethod.GATEWAY_STATE,
          params: gatewayRequestParams,
          jsonrpc: "2.0");

      String jsonGatewayRequestMessage = jsonEncode(gatewayRequestMessage);

      txSocket.send(jsonGatewayRequestMessage);
    }
  }

  void _invalidateGatewayResponseTimer() {
    _gatewayResponseTimer.cancel();
  }

  void _resetGatewayCounters() {
    _registrationRetryCounter = 0;
    _connectRetryCounter = 0;
  }
}
