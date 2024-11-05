// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/model/verto/send/attach_call_message.dart';
import '/peer/peer.dart' if (dart.library.html) '/web/peer.dart';
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
import 'model/call_state.dart';
import 'model/jsonrpc.dart';
import 'model/push_notification.dart';
import 'model/verto/send/pong_message_body.dart';

typedef OnSocketMessageReceived = void Function(TelnyxMessage message);
typedef OnSocketErrorReceived = void Function(TelnyxSocketError message);

/// The TelnyxClient class that can be used to control the SDK. Such as connect,
/// disconnect, check gateway status or create instance of [Call]
///
class _PreferencesStorage {
  static const String _notification_key = 'com.telnyx.webrtc.notification';

  static Future<Map<String, dynamic>?> getMetaData() async {
    String metaData = await getString(_notification_key);
    if (metaData.isEmpty) {
      print("No Metadata found");
      return null;
    }
    saveMetadata("");
    return jsonDecode(metaData);
  }

  static void saveMetadata(String metaData) {
    Logger().i("Save meta data $metaData");
    saveString(_notification_key, metaData);
  }

  static Future<void> saveString(String key, String data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, data);
  }

  static Future<String> getString(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? preferences = prefs.getString(key);
    if (preferences != null) {
      return preferences;
    } else {
      return "";
    }
  }

  static Future<void> saveBool(bool data, String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, data);
  }

  static Future<bool> getBool(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool? value = prefs.getBool(key);
    if (value != null) {
      return value;
    } else {
      return false;
    }
  }
}

class TelnyxClient {
  late OnSocketMessageReceived onSocketMessageReceived;
  late OnSocketErrorReceived onSocketErrorReceived;
  String ringtonePath = "";
  String ringBackpath = "";
  PushMetaData? _pushMetaData;
  bool _isAttaching = false;

  void checkReconnection() {
    // Remember to cancel the subscription when it's no longer needed
    StreamSubscription<List<ConnectivityResult>> subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> connectivityResult) {
      if (connectivityResult.contains(ConnectivityResult.mobile)) {
        _logger.i('Mobile network available.');
        if (activeCalls().isNotEmpty && !_isAttaching) {
          _reconnectToSocket();
        } // Mobile network available.
      } else if (connectivityResult.contains(ConnectivityResult.wifi)) {
        _logger.i('Wi-fi is available.');
        if (activeCalls().isNotEmpty && !_isAttaching) {
          _reconnectToSocket();
        }
        // Wi-fi is available.
        // Note for Android:
        // When both mobile and Wi-Fi are turned on system will return Wi-Fi only as active network type
      } else if (connectivityResult.contains(ConnectivityResult.ethernet)) {
        _logger.i('Ethernet connection available.');
        // Ethernet connection available.
      } else if (connectivityResult.contains(ConnectivityResult.vpn)) {
        // Vpn connection active.
        // Note for iOS and macOS:
        _logger.i('Vpn connection active.');
      } else if (connectivityResult.contains(ConnectivityResult.bluetooth)) {
        _logger.i('Bluetooth connection available.');
        // Bluetooth connection available.
      } else if (connectivityResult.contains(ConnectivityResult.other)) {
        _logger.i(
            'Connected to a network which is not in the above mentioned networks.');
        // Connected to a network which is not in the above mentioned networks.
      } else if (connectivityResult.contains(ConnectivityResult.none)) {
        _logger.i('No available network types');
        // No available network types
      }
      // Received changes in available connectivity types!
    });
  }

  TelnyxClient() {
    // Default implementation of onSocketMessageReceived
    onSocketMessageReceived = (TelnyxMessage message) {
      switch (message.socketMethod) {
        case SocketMethod.INVITE:
          {
            _logger.i(
                'TelnyxClient :: onSocketMessageReceived  Override this on client side: $message');
            break;
          }
        case SocketMethod.BYE:
          {
            _logger.i(
                'TelnyxClient :: onSocketMessageReceived  Override this on client side: $message');
            break;
          }
        default:
          _logger.i(
              'TelnyxClient :: onSocketMessageReceived  Override this on client side: $message');
      }
      _logger.i(
          'TelnyxClient :: onSocketMessageReceived  Override this on client side: $message');
    };

    checkReconnection();
  }

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
  static const int RECONNECT_TIMER = 1000;

  Timer? _gatewayResponseTimer;
  bool _autoReconnectLogin = true;
  bool _waitingForReg = true;
  bool _pendingAnswerFromPush = false;
  bool _pendingDeclineFromPush = false;
  bool _isCallFromPush = false;
  bool _registered = false;
  int _registrationRetryCounter = 0;
  int _connectRetryCounter = 0;
  String gatewayState = GatewayState.IDLE;
  Map<String, Call> calls = {};

  Map<String, Call> activeCalls() {
    return Map.fromEntries(calls.entries
        .where((entry) => entry.value.callState == CallState.active));
  }

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
    return gatewayState;
  }

  /// Handles the push notification received from the backend
  /// and initiates the connection with the provided [pushMetaData]
  /// and [credentialConfig] or [tokenConfig]
  /// If the push notification is received while the client is not connected
  /// Note: Do not call the connect method after calling this method, it implicitly calls the
  /// connect method with the provided [pushMetaData]
  /// and [credentialConfig] or [tokenConfig]
  void handlePushNotification(PushMetaData pushMetaData,
      CredentialConfig? credentialConfig, TokenConfig? tokenConfig) {
    print(jsonEncode(pushMetaData));
    _isCallFromPush = true;

    if (pushMetaData.isAnswer == true) {
      print("_pendingAnswerFromPush true");
      _pendingAnswerFromPush = true;
    } else {
      print("_pendingAnswerFromPush false");
    }

    if (pushMetaData.isDecline == true) {
      _pendingDeclineFromPush = true;
    }

    _connectWithCallBack(pushMetaData, () {
      if (credentialConfig != null) {
        credentialLogin(credentialConfig);
      } else if (tokenConfig != null) {
        tokenLogin(tokenConfig);
      }
    });
  }

  static void setPushMetaData(Map<String, dynamic> pushMetaData,
      {bool isAnswer = false, bool isDecline = false}) {
    Map<String, dynamic> metaData = jsonDecode(pushMetaData["metadata"]);
    metaData["isAnswer"] = isAnswer;
    metaData["isDecline"] = isDecline;
    _PreferencesStorage.saveMetadata(jsonEncode(metaData));
  }

  static Future<Map<String, dynamic>?> getPushData() async {
    return await _PreferencesStorage.getMetaData();
  }

  /// Create a socket connection for
  /// communication with the Telnyx backend
  void _connectWithCallBack(
      PushMetaData? pushMetaData, OnOpenCallback openCallback) {
    _logger.i('connect() ${pushMetaData?.toJson()}');
    if (pushMetaData != null) {
      _pushMetaData = pushMetaData;
    }
    try {
      if (pushMetaData?.voice_sdk_id != null) {
        txSocket.hostAddress =
            "$_storedHostAddress?voice_sdk_id=${pushMetaData?.voice_sdk_id}";
        _logger.i(
            'Connecting to WebSocket with voice_sdk_id :: ${pushMetaData?.voice_sdk_id}');
        print("Connecting to WebSocket :: ${txSocket.hostAddress}");
      } else {
        txSocket.hostAddress = _storedHostAddress;
        _logger.i('connecting to WebSocket $_storedHostAddress');
      }
      txSocket.connect();

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
    } catch (e, s) {
      _logger.e(e.toString(), null, s);
      _connected = false;
      _logger.e('WebSocket $_storedHostAddress error: $e');
    }
  }

  void connectWithToken(TokenConfig tokenConfig) {
    _logger.i('connect()');
    _logger.i('connecting to WebSocket $_storedHostAddress');
    try {
      if (_pushMetaData != null) {
        txSocket.hostAddress =
            "$_storedHostAddress?voice_sdk_id=${_pushMetaData?.voice_sdk_id}";
        _logger.i(
            'Connecting to WebSocket with voice_sdk_id :: ${_pushMetaData?.voice_sdk_id}');
        print("Connecting to WebSocket :: ${txSocket.hostAddress}");
      } else {
        txSocket.hostAddress = _storedHostAddress;
        _logger.i('connecting to WebSocket $_storedHostAddress');
      }
      txSocket.onOpen = () {
        _closed = false;
        _connected = true;
        _logger.i('Web Socket is now connected');
        _onOpen();
        tokenLogin(tokenConfig);
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

  void connectWithCredential(CredentialConfig credentialConfig) {
    _logger.i('connect()');
    try {
      if (_pushMetaData != null) {
        txSocket.hostAddress =
            "$_storedHostAddress?voice_sdk_id=${_pushMetaData?.voice_sdk_id}";
        _logger.i(
            'Connecting to WebSocket with voice_sdk_id :: ${_pushMetaData?.voice_sdk_id}');
        print("Connecting to WebSocket :: ${txSocket.hostAddress}");
      } else {
        txSocket.hostAddress = _storedHostAddress;
        _logger.i('connecting to WebSocket $_storedHostAddress');
      }
      txSocket.onOpen = () {
        _closed = false;
        _connected = true;
        _logger.i('Web Socket is now connected');
        _onOpen();
        credentialLogin(credentialConfig);
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

  @Deprecated(
      "Use connect with token or credential login i.e connectWithCredential(..) or connectWithToken(..)")
  void connect() {
    _logger.i('connect()');
    if (isConnected()) {
      _logger.i('WebSocket $_storedHostAddress is already connected');
      return;
    }
    _logger.i('connecting to WebSocket $_storedHostAddress');
    try {
      if (_pushMetaData != null) {
        txSocket.hostAddress =
            "$_storedHostAddress?voice_sdk_id=${_pushMetaData?.voice_sdk_id}";
        _logger.i(
            'Connecting to WebSocket with voice_sdk_id :: ${_pushMetaData?.voice_sdk_id}');
        print("Connecting to WebSocket :: ${txSocket.hostAddress}");
      } else {
        txSocket.hostAddress = _storedHostAddress;
        _logger.i('connecting to WebSocket $_storedHostAddress');
      }
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
    _isAttaching = true;
    Timer(const Duration(milliseconds: GATEWAY_RESPONSE_DELAY), () {
      _isAttaching = false;
    });

    txSocket.close();
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

  // Public getter to lazily initialize and return the value.
  @Deprecated(
      "telnyxClient.call is deprecated, use telnyxClient.invite() or  telnyxClient.accept()")
  Call get call {
    // If _call is null, initialize it with the default value.

    _call ??= _createCall();
    return _call!;
  }

  void _callEnded() {
    _logger.i('Call Ended');
    _call = null;
  }

  /// Creates an instance of [Call] that can be used to create invitations or
  /// perform common call related functions such as ending the call or placing
  /// yourself on hold/mute.
  Call _createCall() {
    // Set global call parameter
    _call = Call(txSocket, this, sessid, ringtonePath, ringBackpath,
        CallHandler((state) {
      /*
      * initialise this callback to handle call state changes on the client side
      * */
      print("Call state not overridden :Call State Changed to $state");
      _logger.i('Call state not overridden :Call State Changed to $state');
    }), _callEnded);
    return _call!;
  }

  /// Uses the provided [config] to send a credential login message to the Telnyx backend.
  /// If successful, the gateway registration process will start.
  ///
  /// May return a [TelnyxSocketError] in the case of an authentication error
  @Deprecated("Use connectWithCredential(..) instead")
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
      sessionId: sessid,
      userVariables: notificationParams,
      attachCall: "true",
    );
    var loginMessage = LoginMessage(
        id: uuid,
        method: SocketMethod.LOGIN,
        params: loginParams,
        jsonrpc: JsonRPCConstant.jsonrpc);

    String jsonLoginMessage = jsonEncode(loginMessage);
    if (isConnected()) {
      txSocket.send(jsonLoginMessage);
    } else {
      _connectWithCallBack(_pushMetaData, () {
        txSocket.send(jsonLoginMessage);
      });
    }
  }

  /// Uses the provided [config] to send a token login message to the Telnyx backend.
  /// If successful, the gateway registration process will start.
  ///
  /// May return a [TelnyxSocketError] in the case of an authentication error
  @Deprecated("Use connectWithToken(..) instead")
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
        sessionId: sessid,
        attachCall: "true");
    var loginMessage = LoginMessage(
        id: uuid,
        method: SocketMethod.LOGIN,
        params: loginParams,
        jsonrpc: JsonRPCConstant.jsonrpc);

    String jsonLoginMessage = jsonEncode(loginMessage);
    _logger.i('Token Login Message $jsonLoginMessage');
    if (isConnected()) {
      txSocket.send(jsonLoginMessage);
    } else {
      _connectWithCallBack(null, () {
        txSocket.send(jsonLoginMessage);
      });
    }
  }

  // Creates an invitation to send to a [destinationNumber] or SIP Destination
  /// using the provided [callerName], [callerNumber] and a [clientState]
  Call newInvite(String callerName, String callerNumber,
      String destinationNumber, String clientState,
      {Map<String, String> customHeaders = const {}}) {
    Call inviteCall = _createCall();

    inviteCall.sessionCallerName = callerName;
    inviteCall.sessionCallerNumber = callerNumber;
    inviteCall.sessionDestinationNumber = destinationNumber;
    inviteCall.sessionClientState = clientState;
    customHeaders = customHeaders;
    inviteCall.callId = const Uuid().v4();
    var base64State = base64.encode(utf8.encode(clientState));
    updateCall(inviteCall);

    inviteCall.peerConnection = Peer(inviteCall.txSocket);
    inviteCall.peerConnection?.invite(
        callerName,
        callerNumber,
        destinationNumber,
        base64State,
        inviteCall.callId!,
        inviteCall.sessid,
        customHeaders);
    //play ringback tone
    inviteCall.playAudio(ringBackpath);
    inviteCall.callHandler.changeState(CallState.newCall, inviteCall);
    return inviteCall;
  }

  /// Accepts the incoming call specified via the [invite] parameter, sending
  /// your local specified [callerName], [callerNumber] and [clientState]
  Call acceptCall(IncomingInviteParams invite, String callerName,
      String callerNumber, String clientState,
      {bool isAttach = false, Map<String, String> customHeaders = const {}}) {
    Call answerCall = getCallOrNull(invite.callID!) ?? _createCall();
    answerCall.callId = invite.callID;

    answerCall.sessionCallerName = callerName;
    answerCall.sessionCallerNumber = callerNumber;
    answerCall.callState = CallState.active;
    answerCall.sessionDestinationNumber =
        invite.callerIdName ?? "Unknown Caller";
    answerCall.sessionClientState = clientState;

    var destinationNum = invite.callerIdNumber;

    answerCall.peerConnection = Peer(txSocket);
    answerCall.peerConnection?.accept(callerName, callerNumber, destinationNum!,
        clientState, answerCall.callId!, invite, customHeaders, isAttach);
    answerCall.callHandler.changeState(CallState.active, answerCall);
    answerCall.stopAudio();
    if (answerCall.callId != null) {
      updateCall(answerCall);
    }
    return answerCall;
  }

  Call? getCallOrNull(String callId) {
    if (calls.containsKey(callId)) {
      _logger.d("Invite Call found");
      return calls[callId];
    }
    _logger.d("Invite Call not found");
    return null;
  }

  void updateCall(Call call) {
    if (calls.containsKey(call.callId)) {
      calls[call.callId!] = call;
    } else {
      calls[call.callId!] = call;
    }
  }

  /// Closes the socket connection, effectively logging the user out.
  void disconnectWithCallBck(OnCloseCallback? closeCallback) {
    _invalidateGatewayResponseTimer();
    _resetGatewayCounters();
    _logger.i('disconnect()');
    if (_closed) {
      _logger.i('WebSocket is already closed');
      closeCallback?.call(0, 'Client send disconnect');
      return;
    }
    // Don't wait for the WebSocket 'close' event, do it now.
    _closed = true;
    _connected = false;
    _registered = false;
    try {
      txSocket.close();
      Future.delayed(const Duration(milliseconds: 100), () {
        closeCallback?.call(0, 'Client send disconnect');
      });
    } catch (error) {
      _logger.e('close() | error closing the WebSocket: $error');
    }
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
        print('Received WebSocket message :: ${data.toString().trim()}');

        if (data.toString().trim().contains("error")) {
          var errorJson = jsonEncode(data.toString());
          _logger
              .i('Received WebSocket message - Contains Error :: $errorJson');
          try {
            ReceivedResult errorResult =
                ReceivedResult.fromJson(jsonDecode(data.toString()));
            onSocketErrorReceived.call(errorResult.error!);
            print("Error Received ${errorResult.error?.errorMessage}");
            print("Error Received ${errorResult.toJson()}");
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
                      gatewayState = GatewayState.REGED;
                      _waitingForReg = false;
                      var message = TelnyxMessage(
                          socketMethod: SocketMethod.CLIENT_READY,
                          message: mainMessage);
                      onSocketMessageReceived.call(message);
                      if (_isCallFromPush) {
                        //sending attach Call
                        String platform =
                            defaultTargetPlatform == TargetPlatform.android
                                ? "android"
                                : "ios";
                        String pushEnvironment =
                            kDebugMode ? "development" : "production";
                        AttachCallMessage attachCallMessage = AttachCallMessage(
                            method: SocketMethod.ATTACH_CALL,
                            id: const Uuid().v4(),
                            params: Params(
                              userVariables: <dynamic, dynamic>{
                                "push_notification_environment":
                                    pushEnvironment,
                                "push_notification_provider": platform,
                              },
                            ),
                            jsonrpc: "2.0");
                        print(
                            "attachCallMessage :: ${attachCallMessage.toJson()}");
                        txSocket.send(jsonEncode(attachCallMessage));
                        _isCallFromPush = false;
                      }
                      _registered = true;
                    }
                    break;
                  }
                case GatewayState.FAILED:
                  {
                    print("Failed Error");
                    _logger.i(
                        'GATEWAY REGISTRATION FAILED :: ${stateMessage.toString()}');
                    gatewayState = GatewayState.FAILED;
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
                    gatewayState = GatewayState.UNREGED;
                    break;
                  }
                case GatewayState.REGISTER:
                  {
                    _logger
                        .i('GATEWAY REGISTERING :: ${stateMessage.toString()}');
                    gatewayState = GatewayState.REGISTER;
                    break;
                  }
                case GatewayState.UNREGISTER:
                  {
                    _logger.i(
                        'GATEWAY UNREGISTERED :: ${stateMessage.toString()}');
                    gatewayState = GatewayState.UNREGISTER;
                    break;
                  }
                case GatewayState.ATTACHED:
                  {
                    _logger.i('GATEWAY ATTACHED :: ${stateMessage.toString()}');
                    break;
                  }
                default:
                  {
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

          ReceivedMessage clientReadyMessage =
              ReceivedMessage.fromJson(jsonDecode(data.toString()));
          if (clientReadyMessage.voiceSdkId != null) {
            _logger.i('VoiceSdkID :: ${clientReadyMessage.voiceSdkId}');
            _pushMetaData = PushMetaData(
                caller_number: null,
                caller_name: null,
                voice_sdk_id: clientReadyMessage.voiceSdkId);
          } else {
            _logger.e('VoiceSdkID not found');
          }
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
                if (gatewayState != GatewayState.REGED) {
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
                //play ringtone for web
                Call offerCall = _createCall();
                offerCall.callId = invite.inviteParams?.callID;
                updateCall(offerCall);

                onSocketMessageReceived.call(message);

                offerCall.callHandler
                    .changeState(CallState.connecting, offerCall);
                if (!_pendingAnswerFromPush) {
                  offerCall.playRingtone(ringtonePath);
                  offerCall.callHandler
                      .changeState(CallState.ringing, offerCall);
                } else {
                  offerCall.acceptCall(
                      invite.inviteParams!,
                      invite.inviteParams!.calleeIdName ?? "",
                      invite.inviteParams!.callerIdNumber ?? "",
                      "State");
                  _pendingAnswerFromPush = false;
                  offerCall.callHandler
                      .changeState(CallState.active, offerCall);
                }
                if (_pendingDeclineFromPush) {
                  offerCall.endCall(invite.inviteParams?.callID);
                  offerCall.callHandler.changeState(CallState.done, offerCall);
                  _pendingDeclineFromPush = false;
                }
                break;
              }
            case SocketMethod.ATTACH:
              {
                _logger.i('ATTACH RECEIVED :: $messageJson');
                _logger.i('INCOMING INVITATION :: $messageJson');
                ReceivedMessage invite =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                var message = TelnyxMessage(
                    socketMethod: SocketMethod.INVITE, message: invite);
                //play ringtone for web
                Call offerCall = _createCall();
                offerCall.callId = invite.inviteParams?.callID;
                updateCall(offerCall);

                onSocketMessageReceived.call(message);

                offerCall.acceptCall(
                    invite.inviteParams!,
                    invite.inviteParams!.calleeIdName ?? "",
                    invite.inviteParams!.callerIdNumber ?? "",
                    "State",
                    isAttach: true);
                _pendingAnswerFromPush = false;
                // offerCall.callHandler.changeState(CallState.active, offerCall);

                break;
              }
            case SocketMethod.MEDIA:
              {
                _logger.i('MEDIA RECEIVED :: $messageJson');
                ReceivedMessage mediaReceived =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                if (mediaReceived.inviteParams?.sdp != null) {
                  Call? mediaCall = calls[mediaReceived.inviteParams?.callID];
                  if (mediaCall == null) {
                    _logger.d("Error : Call  is null from Media Message");
                    _sendNoCallError();
                    return;
                  }
                  mediaCall?.onRemoteSessionReceived(
                      mediaReceived.inviteParams?.sdp);
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
                Call? answerCall = calls[inviteAnswer.inviteParams?.callID];
                if (answerCall == null) {
                  _logger.d("Error : Call  is null from Answer Message");
                  _sendNoCallError();
                  return;
                }
                var message = TelnyxMessage(
                    socketMethod: SocketMethod.ANSWER, message: inviteAnswer);
                if (inviteAnswer.inviteParams?.sdp != null) {
                  answerCall
                      ?.onRemoteSessionReceived(inviteAnswer.inviteParams?.sdp);
                  onSocketMessageReceived(message);
                } else if (earlySDP) {
                  onSocketMessageReceived(message);
                } else {
                  _logger.d(
                      'No SDP provided for Answer or Media, cannot initialize call');
                  answerCall.endCall(inviteAnswer.inviteParams?.callID);
                }
                earlySDP = false;
                answerCall.stopAudio();
                break;
              }
            case SocketMethod.BYE:
              {
                _logger.i('BYE RECEIVED :: $messageJson');
                ReceivedMessage bye =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                Call? byeCall = calls[bye.inviteParams?.callID];
                if (byeCall == null) {
                  _logger.d("Error : Call  is null from Bye Message");
                  _sendNoCallError();
                  return;
                }
                var message =
                    TelnyxMessage(socketMethod: SocketMethod.BYE, message: bye);
                onSocketMessageReceived(message);
                byeCall.stopAudio();
                byeCall.peerConnection?.closeSession();
                byeCall.stopAudio();
                calls.remove(byeCall.callId);
                break;
              }
            case SocketMethod.RINGING:
              {
                _logger.i('RINGING RECEIVED :: $messageJson');
                ReceivedMessage ringing =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                Call? ringingCall = calls[ringing.inviteParams?.callID];
                if (ringingCall == null) {
                  _logger.d("Error : Call  is null from Ringing Message");
                  _sendNoCallError();
                  return;
                }

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

  void _sendNoCallError() {
    var error = TelnyxSocketError(
        errorCode: 404, errorMessage: TelnyxErrorConstants.callNotFound);
    onSocketErrorReceived(error);
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
    _waitingForReg = true;
    gatewayState = GatewayState.IDLE;
  }
}
