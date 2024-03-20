// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'package:logger/logger.dart';
import 'package:telnyx_webrtc/model/verto/send/attach_call_message.dart';
import '/call.dart';
import '/config/telnyx_config.dart';
import '/model/gateway_state.dart';
import '/model/socket_method.dart';
import '/model/telnyx_socket_error.dart';
import '/model/verto/receive/received_message_body.dart';
import '/model/verto/send/gateway_request_message_body.dart';
import '/model/verto/send/login_message_body.dart';
import '/model/telnyx_message.dart';
import 'package:telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_webrtc/tx_socket_web.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import 'model/jsonrpc.dart';
import 'model/push_notification.dart';
import 'model/verto/send/pong_message_body.dart';

typedef OnSocketMessageReceived = void Function(TelnyxMessage message);
typedef OnSocketErrorReceived = void Function(TelnyxSocketError message);

/// The TelnyxClient class that can be used to control the SDK. Such as connect,
/// disconnect, check gateway status or create instance of [Call]
class TelnyxClient {
  late OnSocketMessageReceived onSocketMessageReceived;
  late OnSocketErrorReceived onSocketErrorReceived;
  String ringtonePath = "";
  String ringBackpath = "";

  TelnyxClient({this.ringtonePath = '', this.ringBackpath = ''});

  TxSocket txSocket = TxSocket("wss://rtc.telnyx.com:443");
  bool _closed = false;
  bool _connected = false;
  final _logger = Logger();

  /// The current session ID related to this client
  String sessid = const Uuid().v4();


  // Gateway registration variables
  static const int RETRY_REGISTER_TIME = 3;
  static const int RETRY_CONNECT_TIME = 3;
  static const int GATEWAY_RESPONSE_DELAY = 3000;

  Timer? _gatewayResponseTimer;
  bool _autoReconnectLogin = true;
  bool _waitingForReg = true;
  bool _pendingAnswerFromPush = false;
  bool _registered = false;
  int _registrationRetryCounter = 0;
  int _connectRetryCounter = 0;
  String _gatewayState = GatewayState.IDLE;

  // For instances where the SDP is not contained within ANSWER, but received early via a MEDIA message
  bool earlySDP = false;

  final String _storedHostAddress = "wss://rtc.telnyx.com:443";
  CredentialConfig? storedCredentialConfig;
  TokenConfig? storedTokenConfig;

  /// Returns whether or not the client is connected to the socket connection
  bool isConnected() {
    return _connected;
  }

  /// Returns the current Gateway state for the socket connection
  String getGatewayStatus() {
    return _gatewayState;
  }

  void handlePushNotification(PushMetaData pushMetaData,CredentialConfig? credentialConfig,TokenConfig? tokenConfig){
    _pendingAnswerFromPush = true;
    _connectWithCallBack(pushMetaData, (){
      if (credentialConfig != null) {
        credentialLogin(credentialConfig);
      } else if (tokenConfig != null) {
        tokenLogin(tokenConfig);
      }
    });
  }

  /// Create a socket connection for
  /// communication with the Telnyx backend
  void _connectWithCallBack(PushMetaData? pushMetaData,OnOpenCallback openCallback) {
    _logger.i('connect()');
    if (isConnected() && pushMetaData?.voice_sdk_id == null) {
      _logger.i('WebSocket $_storedHostAddress is already connected');
      return;
    }
    _logger.i('connecting to WebSocket $_storedHostAddress');
    try {
      txSocket.onOpen = () {
        _closed = false;
        _connected = true;
        _logger.i('Web Socket is now connected');
        _onOpen();
        openCallback.call();
      };

      txSocket.onMessage = (dynamic data) {
        _onMessage(data);
      };

      txSocket.onClose = (int closeCode, String closeReason) {
        _logger.i('Closed [$closeCode, $closeReason]!');
        _connected = false;
        _onClose(true, closeCode, closeReason);
      };

      if(pushMetaData?.voice_sdk_id != null){
        txSocket.hostAddress = "$_storedHostAddress?voice_sdk_id=${pushMetaData?.voice_sdk_id}";
        _logger.i('Connecting to WebSocket with voice_sdk_id :: ${pushMetaData?.voice_sdk_id}');
      }
      txSocket.connect();
    } catch (e, s) {
      _logger.e(e.toString(), null, s);
      _connected = false;
      _logger.e('WebSocket $_storedHostAddress error: $e');
    }
  }

  void connect() {
    _logger.i('connect()');
    if (isConnected()) {
      _logger.i('WebSocket $_storedHostAddress is already connected');
      return;
    }
    _logger.i('connecting to WebSocket $_storedHostAddress');
    try {
      txSocket.onOpen = () {
        _closed = false;
        _connected = true;
        _logger.i('Web Socket is now connected');
        _onOpen();
      };

      txSocket.onMessage = (dynamic data) {
        _onMessage(data);
      };

      txSocket.onClose = (int closeCode, String closeReason) {
        _logger.i('Closed [$closeCode, $closeReason]!');
        _connected = false;
        _onClose(true, closeCode, closeReason);
      };

      txSocket.connect();
    } catch (e, s) {
      _logger.e(e.toString(), null, s);
      _connected = false;
      _logger.e('WebSocket $_storedHostAddress error: $e');
    }
  }

  void _reconnectToSocket() {
    txSocket.close();
    txSocket.connect();
    // Delay to allow connection
    Timer(const Duration(seconds: 1), () {
      if (storedCredentialConfig != null) {
        credentialLogin(storedCredentialConfig!);
      } else if (storedTokenConfig != null) {
        tokenLogin(storedTokenConfig!);
      }
    });
  }

  /// The current instance of [Call] associated with this client. Can be used
  /// to call call related functions such as hold/mute
  Call? _call;

  //if there's a bye we'll need to reinitialize call object
  bool _pendingBye = false;
  // Public getter to lazily initialize and return the value.
  Call get call {
    // If _call is null, initialize it with the default value.
    if(_pendingBye){
      _callEnded();
    }
    _call ??= _createCall();
    return _call!;
  }

  void _callEnded() {
    _call = null;
  }

  /// Creates an instance of [Call] that can be used to create invitations or
  /// perform common call related functions such as ending the call or placing
  /// yourself on hold/mute.
  Call _createCall() {
    // Set global call parameter
    _call = Call(txSocket, sessid, ringtonePath, ringBackpath,_callEnded);
    return _call!;
  }

  /// Uses the provided [config] to send a credential login message to the Telnyx backend.
  /// If successful, the gateway registration process will start.
  ///
  /// May return a [TelnyxSocketError] in the case of an authentication error
  void credentialLogin(CredentialConfig config) {
    storedCredentialConfig = config;
    var uuid = const Uuid().v4();
    var user = config.sipUser;
    var password = config.sipPassword;
    var fcmToken = config.notificationToken;
    ringBackpath = config.ringbackPath ?? "";
    ringtonePath = config.ringTonePath ?? "";
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
        userVariables: notificationParams,attachCall: "true",);
    var loginMessage = LoginMessage(
        id: uuid,
        method: SocketMethod.LOGIN,
        params: loginParams,
        jsonrpc: JsonRPCConstant.jsonrpc);

    String jsonLoginMessage = jsonEncode(loginMessage);

    txSocket.send(jsonLoginMessage);
  }

  /// Uses the provided [config] to send a token login message to the Telnyx backend.
  /// If successful, the gateway registration process will start.
  ///
  /// May return a [TelnyxSocketError] in the case of an authentication error
  void tokenLogin(TokenConfig config) {
    storedTokenConfig = config;
    var uuid = const Uuid().v4();
    var token = config.sipToken;
    var fcmToken = config.notificationToken;
    ringBackpath = config.ringbackPath ?? "";
    ringtonePath = config.ringTonePath ?? "";
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
        loginToken: token,
        loginParams: [],
        userVariables: notificationParams,
        sessionId: sessid,attachCall: "true");
    var loginMessage = LoginMessage(
        id: uuid,
        method: SocketMethod.LOGIN,
        params: loginParams,
        jsonrpc: JsonRPCConstant.jsonrpc);

    String jsonLoginMessage = jsonEncode(loginMessage);
    _logger.i('Token Login Message $jsonLoginMessage');
    txSocket.send(jsonLoginMessage);
  }

  /// Closes the socket connection, effectively logging the user out.
  void disconnect() {
    _invalidateGatewayResponseTimer();
    _resetGatewayCounters();
    _logger.i('disconnect()');
    if (_closed) return;
    // Don't wait for the WebSocket 'close' event, do it now.
    _closed = true;
    _connected = false;
    _registered = false;
    _onClose(true, 0, 'Client send disconnect');
    try {
      txSocket.close();
    } catch (error) {
      _logger.e('close() | error closing the WebSocket: $error');
    }
  }

  /// WebSocket Event Handlers
  void _onOpen() {
    _logger.i('WebSocket connected');
  }

  void _onClose(bool wasClean, int code, String reason) {
    _logger.i('WebSocket closed');
    if (wasClean == false) {
      _logger.i('WebSocket abrupt disconnection');
    }
  }

  void _onMessage(dynamic data) {
    _logger.i('DEBUG MESSAGE: ${data.toString().trim()}');
    if (data != null) {
      if (data.toString().trim().isNotEmpty) {
        _logger.i('Received WebSocket message :: ${data.toString().trim()}');

        if (data.toString().trim().contains("error")) {
          var errorJson = jsonEncode(data.toString());
          _logger
              .i('Received WebSocket message - Contains Error :: $errorJson');
          try {
            ReceivedResult errorResult =
                ReceivedResult.fromJson(jsonDecode(data.toString()));
            onSocketErrorReceived.call(errorResult.error!);
          } on Exception catch (e) {
            _logger.e('Error parsing JSON: $e');
          }
        }

        //Login success
        if (data.toString().trim().contains("result")) {
          var paramJson = jsonEncode(data.toString());
          _logger
              .i('Received WebSocket message - Contains Result :: $paramJson');

          try {
            ReceivedResult stateMessage =
                ReceivedResult.fromJson(jsonDecode(data.toString()));

            var mainMessage = ReceivedMessage(
                jsonrpc: stateMessage.jsonrpc,
                method: SocketMethod.GATEWAY_STATE,
                stateParams: stateMessage.resultParams?.stateParams);

            if (stateMessage.resultParams != null) {
              switch (stateMessage.resultParams?.stateParams?.state) {
                case GatewayState.REGED:
                  {
                    if (!_registered) {
                      _logger.i(
                          'GATEWAY REGISTERED :: ${stateMessage.toString()}');
                      _invalidateGatewayResponseTimer();
                      _resetGatewayCounters();
                      _gatewayState = GatewayState.REGED;
                      _waitingForReg = false;
                      var message = TelnyxMessage(
                          socketMethod: SocketMethod.CLIENT_READY,
                          message: mainMessage);
                      onSocketMessageReceived.call(message);
                      if(_pendingAnswerFromPush){
                        _pendingAnswerFromPush = false;
                        //sending attach Call
                        String platform = defaultTargetPlatform == TargetPlatform.android ? "android" : "ios";

                        AttachCallMessage attachCallMessage = AttachCallMessage(
                            method: SocketMethod.ATTACH_CALL,
                            id: const Uuid().v4(),
                            params: Params(
                                pushNotificationProvider: platform,
                                userVariables: <dynamic, dynamic>{"push_notification_environment":"debug"},
                                loginParams: <dynamic, dynamic>{}),jsonrpc: "2.0");
                        txSocket.send(jsonEncode(attachCallMessage));
                      }
                      _registered = true;
                    }
                    break;
                  }
                case GatewayState.FAILED:
                  {
                    _logger.i(
                        'GATEWAY REGISTRATION FAILED :: ${stateMessage.toString()}');
                    _gatewayState = GatewayState.FAILED;
                    _invalidateGatewayResponseTimer();
                    var error = TelnyxSocketError(
                        errorCode: TelnyxErrorConstants.gatewayFailedErrorCode,
                        errorMessage: TelnyxErrorConstants.gatewayFailedError);
                    onSocketErrorReceived(error);
                    break;
                  }
                case GatewayState.UNREGED:
                  {
                    _logger.i('GATEWAY UNREGED :: ${stateMessage.toString()}');
                    _gatewayState = GatewayState.UNREGED;
                    break;
                  }
                case GatewayState.REGISTER:
                  {
                    _logger
                        .i('GATEWAY REGISTERING :: ${stateMessage.toString()}');
                    _gatewayState = GatewayState.REGISTER;
                    break;
                  }
                case GatewayState.UNREGISTER:
                  {
                    _logger.i(
                        'GATEWAY UNREGISTERED :: ${stateMessage.toString()}');
                    _gatewayState = GatewayState.UNREGISTER;
                    break;
                  }
                default:
                  {
                    _invalidateGatewayResponseTimer();
                    _resetGatewayCounters();
                    _logger.i(
                        'GATEWAY REGISTRATION :: Unknown State ${stateMessage.toString()}');
                  }
              }
            }
          } on Exception catch (e) {
            _logger.e('Error parsing JSON: $e');
          }
        } else if (data.toString().trim().contains("method")) {
          //Received Telnyx Method Message
          var messageJson = jsonDecode(data.toString());
          _logger.i(
              'Received WebSocket message - Contains Method :: $messageJson');
          switch (messageJson['method']) {
            case SocketMethod.PING:
              {
                var result = Result(message: "PONG", sessid: sessid);
                var pongMessage = PongMessage(
                    jsonrpc: JsonRPCConstant.jsonrpc,
                    id: const Uuid().v4(),
                    result: result);
                String jsonPongMessage = jsonEncode(pongMessage);
                txSocket.send(jsonPongMessage);
                break;
              }
            case SocketMethod.CLIENT_READY:
              {
                if (_gatewayState != GatewayState.REGED) {
                  _logger.i('Retrieving Gateway state...');
                  if (_waitingForReg) {
                    _requestGatewayStatus();
                    _gatewayResponseTimer = Timer(
                        const Duration(milliseconds: GATEWAY_RESPONSE_DELAY),
                        () {
                      if (_registrationRetryCounter < RETRY_REGISTER_TIME) {
                        if (_waitingForReg) {
                          _onMessage(data);
                        }
                        _registrationRetryCounter++;
                      } else {
                        _logger.i('GATEWAY REGISTRATION TIMEOUT');
                        var error = TelnyxSocketError(
                            errorCode:
                                TelnyxErrorConstants.gatewayTimeoutErrorCode,
                            errorMessage:
                                TelnyxErrorConstants.gatewayTimeoutError);
                        onSocketErrorReceived(error);
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
                _logger.i('INCOMING INVITATION :: $messageJson');
                ReceivedMessage invite =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                var message = TelnyxMessage(
                    socketMethod: SocketMethod.INVITE, message: invite);

                call.playAudio(ringtonePath);
                onSocketMessageReceived.call(message);
                break;
              }
            case SocketMethod.MEDIA:
              {
                _logger.i('MEDIA RECEIVED :: $messageJson');
                ReceivedMessage mediaReceived =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                if (mediaReceived.inviteParams?.sdp != null) {
                  call?.onRemoteSessionReceived(mediaReceived.inviteParams?.sdp);
                  earlySDP = true;
                } else {
                  _logger.d('No SDP contained within Media Message');
                }
                break;
              }
            case SocketMethod.ANSWER:
              {
                _logger.i('INVITATION ANSWERED :: $messageJson');
                ReceivedMessage inviteAnswer =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                var message = TelnyxMessage(
                    socketMethod: SocketMethod.ANSWER, message: inviteAnswer);
                if (inviteAnswer.inviteParams?.sdp != null) {
                  call?.onRemoteSessionReceived(inviteAnswer.inviteParams?.sdp);
                  onSocketMessageReceived.call(message);
                } else if (earlySDP) {
                  onSocketMessageReceived.call(message);
                } else {
                  _logger.d(
                      'No SDP provided for Answer or Media, cannot initialize call');
                  call.endCall(inviteAnswer.inviteParams?.callID);
                }
                earlySDP = false;
                call.stopAudio();
                break;
              }
            case SocketMethod.BYE:
              {
                _logger.i('BYE RECEIVED :: $messageJson');
                ReceivedMessage bye =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                var message =
                    TelnyxMessage(socketMethod: SocketMethod.BYE, message: bye);
                onSocketMessageReceived(message);
                call.stopAudio();
                _pendingBye = true;
                break;
              }
            case SocketMethod.RINGING:
              {
                _logger.i('RINGING RECEIVED :: $messageJson');
                ReceivedMessage ringing =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                _logger.i(
                    'Telnyx Leg ID :: ${ringing.inviteParams?.telnyxLegId.toString()}');
                var message = TelnyxMessage(
                    socketMethod: SocketMethod.RINGING, message: ringing);
                onSocketMessageReceived(message);
                break;
              }
          }
        } else {
          _logger.i('Received and ignored empty packet');
        }
      } else {
        _logger.i('Received and ignored empty packet');
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
          jsonrpc: JsonRPCConstant.jsonrpc);

      String jsonGatewayRequestMessage = jsonEncode(gatewayRequestMessage);

      txSocket.send(jsonGatewayRequestMessage);
    }
  }

  void _invalidateGatewayResponseTimer() {
    _gatewayResponseTimer?.cancel();
  }

  void _resetGatewayCounters() {
    _registrationRetryCounter = 0;
    _connectRetryCounter = 0;
  }
}
