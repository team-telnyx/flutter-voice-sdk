import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/network_reason.dart';
import 'package:telnyx_webrtc/model/verto/send/attach_call_message.dart';
import 'package:telnyx_webrtc/peer/peer.dart'
    if (dart.library.html) 'package:telnyx_webrtc/peer/web/peer.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/gateway_state.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/gateway_request_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/login_message_body.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_webrtc/tx_socket_web.dart';
import 'package:telnyx_webrtc/utils/constants.dart';
import 'package:telnyx_webrtc/utils/logging/custom_logger.dart';
import 'package:telnyx_webrtc/utils/logging/default_logger.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_webrtc/utils/preference_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/jsonrpc.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/model/verto/send/pong_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/disable_push_body.dart';

/// Callback for when the socket receives a message
typedef OnSocketMessageReceived = void Function(TelnyxMessage message);

/// Callback for when the socket receives an error
typedef OnSocketErrorReceived = void Function(TelnyxSocketError message);

/// The TelnyxClient class that can be used to control the SDK. Such as connect,
/// disconnect, check gateway status or create instance of [Call] to make calls.
class TelnyxClient {
  /// Callback for when the socket receives a message
  late OnSocketMessageReceived onSocketMessageReceived;

  /// Callback for when the socket receives an error
  late OnSocketErrorReceived onSocketErrorReceived;

  /// The path to the ringtone file (audio to play when receiving a call)
  String _ringtonePath = '';

  /// The path to the ringback file (audio to play when calling)
  String _ringBackpath = '';

  CustomLogger _logger = DefaultLogger();

  PushMetaData? _pushMetaData;
  bool _isAttaching = false;
  bool _debug = false;

  // Map to track reconnection timers for each call
  final Map<String?, Timer> _reconnectionTimers = {};

  /// Default constructor for the TelnyxClient
  TelnyxClient() {
    onSocketMessageReceived = (TelnyxMessage message) {
      switch (message.socketMethod) {
        case SocketMethod.invite:
          {
            GlobalLogger().i(
              'TelnyxClient :: onSocketMessageReceived  Override this on client side: ${message.message}',
            );
            break;
          }
        case SocketMethod.bye:
          {
            GlobalLogger().i(
              'TelnyxClient :: onSocketMessageReceived  Override this on client side: ${message.message}',
            );
            break;
          }
        default:
          GlobalLogger().i(
            'TelnyxClient :: onSocketMessageReceived  Override this on client side: ${message.message}',
          );
      }
      GlobalLogger().i(
        'TelnyxClient :: onSocketMessageReceived  Override this on client side: ${message.message}',
      );
    };

    _checkReconnection();
  }

  /// The current instance of [TxSocket] associated with this client
  TxSocket txSocket = TxSocket(
    DefaultConfig.socketHostAddress,
  );

  bool _closed = false;
  bool _connected = false;

  /// The current session ID related to this client
  String sessid = const Uuid().v4();

  Timer? _gatewayResponseTimer;
  bool _waitingForReg = true;
  bool _pendingAnswerFromPush = false;
  bool _pendingDeclineFromPush = false;
  bool _isCallFromPush = false;
  bool _registered = false;
  int _registrationRetryCounter = 0;

  bool _autoReconnectLogin = true;
  int _connectRetryCounter = 0;

  /// The current gateway state for the socket connection
  String gatewayState = GatewayState.idle;

  /// The current gateway response time for the socket connection
  Map<String, Call> calls = {};

  /// The current active calls being handled by the TelnyxClient instance
  /// The Map key is the callId [String] and the value is the [Call] instance
  Map<String, Call> activeCalls() {
    return Map.fromEntries(
      calls.entries.where((entry) =>
          entry.value.callState == CallState.active ||
          entry.value.callState == CallState.dropped ||
          entry.value.callState == CallState.reconnecting,),
    );
  }

  /// Called when a call state changes to active
  /// This will cancel any reconnection timer for the call
  void onCallStateChangedToActive(String? callId) {
    if (callId != null) {
      GlobalLogger().i(
          'Call $callId state changed to ACTIVE, cancelling reconnection timer',);
      _cancelReconnectionTimer(callId);
    }
  }

  // For instances where the SDP is not contained within ANSWER, but received early via a MEDIA message
  bool _earlySDP = false;

  final String _storedHostAddress = DefaultConfig.socketHostAddress;

  CredentialConfig? _storedCredentialConfig;

  TokenConfig? _storedTokenConfig;

  /// The stored [CredentialConfig] for the client - if no stored credential is present, this will be null
  CredentialConfig? get storedCredential => _storedCredentialConfig;

  /// The stored [TokenConfig] for the client - if no stored token is present, this will be null
  TokenConfig? get storedToken => _storedTokenConfig;

  /// Returns whether or not the client is connected to the socket connection
  bool isConnected() {
    return _connected;
  }

  /// Returns the current Gateway state for the socket connection
  String getGatewayStatus() {
    return gatewayState;
  }

  void _checkReconnection() {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> connectivityResult) {
      if (activeCalls().isEmpty || _isAttaching) return;

      if (connectivityResult.contains(ConnectivityResult.none)) {
        GlobalLogger().i('No available network types');
        _handleNetworkLost();
        return;
      }

      if (connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi)) {
        GlobalLogger().i('Network available: ${connectivityResult.join(", ")}');
        if (activeCalls().isNotEmpty && !_isAttaching) {
          _handleNetworkReconnection(NetworkReason.networkSwitch);
        }
      }
    });
  }

  /// Set the custom logger for the SDK
  void setCustomLogger(CustomLogger logger) {
    _logger = logger;
    GlobalLogger.logger = logger;
  }

  /// Set or adjust the log level for the SDK
  void setLogLevel(LogLevel level) {
    _logger.setLogLevel(level);
  }

  /// Get the custom logger for the SDK
  CustomLogger get logger => _logger;

  void _handleNetworkLost() {
    for (var call in activeCalls().values) {
      call.callHandler.onCallStateChanged
          .call(CallState.dropped.withReason(NetworkReason.networkLost));
      // Start a reconnection timeout timer for this call
      _startReconnectionTimer(call);
    }
  }

  void _handleNetworkReconnection(NetworkReason reason) {
    _reconnectToSocket();
    for (var call in activeCalls().values) {
      if (call.callState.isDropped) {
        call.callHandler.onCallStateChanged
            .call(CallState.reconnecting.withReason(reason));

        // Start a reconnection timeout timer for this call
        _startReconnectionTimer(call);
      }
    }
  }

  /// Starts a reconnection timer for a call
  /// If the call is still in RECONNECTING state after the timeout,
  /// it will be marked as DROPPED
  void _startReconnectionTimer(Call call) {
    // Cancel any existing timer for this call
    _cancelReconnectionTimer(call.callId);

    GlobalLogger().i('Starting reconnection timer for call ${call.callId}');

    // Create a new timer
    _reconnectionTimers[call.callId] = Timer(
      Duration(
          milliseconds: _storedCredentialConfig?.reconnectionTimeout ??
              _storedTokenConfig?.reconnectionTimeout ??
              Constants.reconnectionTimeout,),
      () {
        // Check if the call is still in the reconnecting state
        if (calls.containsKey(call.callId)) {
          GlobalLogger().i('Reconnection timeout for call ${call.callId}');

          // Change the call state to dropped
          call.callHandler.onCallStateChanged
              .call(CallState.dropped.withReason(NetworkReason.networkLost));

          // End the call
          call.endCall();
        }
        // Remove the timer from the map
        _reconnectionTimers.remove(call.callId);
      },
    );
  }

  /// Cancels the reconnection timer for a call
  void _cancelReconnectionTimer(String? callId) {
    if (callId != null && _reconnectionTimers.containsKey(callId)) {
      _reconnectionTimers[callId]?.cancel();
      _reconnectionTimers.remove(callId);
      GlobalLogger().i('Cancelled reconnection timer for call $callId');
    }
  }

  /// Handles the push notification received from the backend
  /// and initiates the connection with the provided [pushMetaData]
  /// and [credentialConfig] or [tokenConfig]
  /// If the push notification is received while the client is not connected
  /// Note: Do not call the connect method after calling this method, it implicitly calls the
  /// connect method with the provided [pushMetaData]
  /// and [credentialConfig] or [tokenConfig]
  void handlePushNotification(
    PushMetaData pushMetaData,
    CredentialConfig? credentialConfig,
    TokenConfig? tokenConfig,
  ) {
    GlobalLogger().i('TelnyxClient.handlePushNotification: Called. PushMetaData: ${jsonEncode(pushMetaData.toJson())}');
    _isCallFromPush = true;

    if (pushMetaData.isAnswer == true) {
      GlobalLogger().i('TelnyxClient.handlePushNotification: _pendingAnswerFromPush will be set to true');
      _pendingAnswerFromPush = true;
    } else {
      GlobalLogger().i('TelnyxClient.handlePushNotification: _pendingAnswerFromPush remains false');
    }

    if (pushMetaData.isDecline == true) {
      GlobalLogger().i('TelnyxClient.handlePushNotification: _pendingDeclineFromPush will be set to true');
      _pendingDeclineFromPush = true;
    } else {
      GlobalLogger().i('TelnyxClient.handlePushNotification: _pendingDeclineFromPush remains false');
    }

    _connectWithCallBack(pushMetaData, () {
      if (credentialConfig != null) {
        credentialLogin(credentialConfig);
      } else if (tokenConfig != null) {
        tokenLogin(tokenConfig);
      }
    });
  }

  /// Sets the push metadata for the client and saves it to the shared preferences
  /// The [isAnswer] flag is used to determine if the push notification indicates that we should answer the pending invite
  /// The [isDecline] flag is used to determine if the push notification indicates that we should decline the pending invite
  static void setPushMetaData(
    Map<String, dynamic> pushMetaData, {
    bool isAnswer = false,
    bool isDecline = false,
  }) {
    final Map<String, dynamic> metaData = jsonDecode(pushMetaData['metadata']);
    metaData['isAnswer'] = isAnswer;
    metaData['isDecline'] = isDecline;
    PreferencesStorage.saveMetadata(jsonEncode(metaData));
  }

  /// Gets the push metadata for the client
  static Future<Map<String, dynamic>?> getPushData() async {
    return await PreferencesStorage.getMetaData();
  }

  /// Clears the push metadata for the client
  static void clearPushMetaData() {
    PreferencesStorage.saveMetadata('');
  }

  /// Create a socket connection for
  /// communication with the Telnyx backend
  void _connectWithCallBack(
    PushMetaData? pushMetaData,
    OnOpenCallback openCallback,
  ) {
    GlobalLogger().i('TelnyxClient._connectWithCallBack: Called. PushMetaData: ${pushMetaData?.toJson()}');
    if (pushMetaData != null) {
      _pushMetaData = pushMetaData;
    }
    try {
      if (pushMetaData?.voiceSdkId != null) {
        txSocket.hostAddress =
            '$_storedHostAddress?voice_sdk_id=${pushMetaData?.voiceSdkId}';
        GlobalLogger().i(
          'Connecting to WebSocket with voice_sdk_id :: ${pushMetaData?.voiceSdkId}',
        );
      } else {
        txSocket.hostAddress = _storedHostAddress;
        GlobalLogger().i('TelnyxClient._connectWithCallBack: connecting to WebSocket $_storedHostAddress');
      }
      txSocket
        ..connect()
        ..onOpen = () {
          _closed = false;
          _connected = true;
          GlobalLogger().i('TelnyxClient._connectWithCallBack (via _onOpen): Web Socket is now connected');
          _onOpen();
          openCallback.call();
        }
        ..onMessage = (dynamic data) {
          _onMessage(data);
        }
        ..onClose = (int closeCode, String closeReason) {
          GlobalLogger().i('Closed [$closeCode, $closeReason]!');
          _connected = false;
          _onClose(true, closeCode, closeReason);
        };
    } catch (e, string) {
      GlobalLogger().e('${e.toString()} :: $string');
      _connected = false;
      GlobalLogger().e('WebSocket $_storedHostAddress error: $e');
    }
  }

  /// Connects to the WebSocket using the provided [tokenConfig]
  void connectWithToken(TokenConfig tokenConfig) {
    // First check if there is a custom logger set within the config - if so, we set it here
    _logger = tokenConfig.customLogger ?? DefaultLogger();
    GlobalLogger.logger = _logger;
    GlobalLogger().i('TelnyxClient.connectWithToken: Attempting to connect.');

    // Now that a logger is set, we can set the log level
    _logger
      ..setLogLevel(tokenConfig.logLevel)
      ..log(LogLevel.info, 'connect()')
      ..log(LogLevel.info, 'connecting to WebSocket $_storedHostAddress');
    try {
      if (_pushMetaData != null) {
        txSocket.hostAddress =
            '$_storedHostAddress?voice_sdk_id=${_pushMetaData?.voiceSdkId}';
        GlobalLogger().i(
          'Connecting to WebSocket with voice_sdk_id :: ${_pushMetaData?.voiceSdkId}',
        );
      } else {
        txSocket.hostAddress = _storedHostAddress;
        GlobalLogger().i('connecting to WebSocket $_storedHostAddress');
      }
      txSocket
        ..onOpen = () {
          _closed = false;
          _connected = true;
          GlobalLogger().i('TelnyxClient.connectWithToken (via _onOpen): Web Socket is now connected');
          _onOpen();
          tokenLogin(tokenConfig);
        }
        ..onMessage = (dynamic data) {
          _onMessage(data);
        }
        ..onClose = (int closeCode, String closeReason) {
          GlobalLogger().i('Closed [$closeCode, $closeReason]!');
          _connected = false;
          _onClose(true, closeCode, closeReason);
        }
        ..connect();
    } catch (e) {
      GlobalLogger().e(e.toString());
      _connected = false;
      GlobalLogger().e('WebSocket $_storedHostAddress error: $e');
    }
  }

  /// Connects to the WebSocket using the provided [CredentialConfig]
  void connectWithCredential(CredentialConfig credentialConfig) {
    // First check if there is a custom logger set within the config - if so, we set it here
    // Use custom logger if provided or fallback to default.
    _logger = credentialConfig.customLogger ?? DefaultLogger();
    GlobalLogger.logger = _logger;
    GlobalLogger().i('TelnyxClient.connectWithCredential: Attempting to connect.');

    // Now that a logger is set, we can set the log level
    _logger
      ..setLogLevel(credentialConfig.logLevel)
      ..log(LogLevel.info, 'connect()');
    try {
      if (_pushMetaData != null) {
        txSocket.hostAddress =
            '$_storedHostAddress?voice_sdk_id=${_pushMetaData?.voiceSdkId}';
        GlobalLogger().i(
          'Connecting to WebSocket with voice_sdk_id :: ${_pushMetaData?.voiceSdkId}',
        );
      } else {
        txSocket.hostAddress = _storedHostAddress;
        GlobalLogger().i('connecting to WebSocket $_storedHostAddress');
      }
      txSocket
        ..onOpen = () {
          _closed = false;
          _connected = true;
          GlobalLogger().i('TelnyxClient.connectWithCredential (via _onOpen): Web Socket is now connected');
          _onOpen();
          credentialLogin(credentialConfig);
        }
        ..onMessage = (dynamic data) {
          _onMessage(data);
        }
        ..onClose = (int closeCode, String closeReason) {
          GlobalLogger().i('Closed [$closeCode, $closeReason]!');
          _connected = false;
          _onClose(true, closeCode, closeReason);
        }
        ..connect();
    } catch (e) {
      GlobalLogger().e(e.toString());
      _connected = false;
      GlobalLogger().e('WebSocket $_storedHostAddress error: $e');
    }
  }

  @Deprecated(
    'Use connect with token or credential login i.e connectWithCredential(..) or connectWithToken(..)',
  )

  /// Connects to the WebSocket with a previously provided [Config]
  void connect() {
    GlobalLogger().i('connect()');
    if (isConnected()) {
      GlobalLogger().i('WebSocket $_storedHostAddress is already connected');
      return;
    }
    GlobalLogger().i('connecting to WebSocket $_storedHostAddress');
    try {
      if (_pushMetaData != null) {
        txSocket.hostAddress =
            '$_storedHostAddress?voice_sdk_id=${_pushMetaData?.voiceSdkId}';
        GlobalLogger().i(
          'Connecting to WebSocket with voice_sdk_id :: ${_pushMetaData?.voiceSdkId}',
        );
      } else {
        txSocket.hostAddress = _storedHostAddress;
        GlobalLogger().i('connecting to WebSocket $_storedHostAddress');
      }
      txSocket
        ..onOpen = () {
          _closed = false;
          _connected = true;
          GlobalLogger().i('Web Socket is now connected');
          _onOpen();
        }
        ..onMessage = (dynamic data) {
          _onMessage(data);
        }
        ..onClose = (int closeCode, String closeReason) {
          GlobalLogger().i('Closed [$closeCode, $closeReason]!');
          _connected = false;
          _onClose(true, closeCode, closeReason);
        }
        ..connect();
    } catch (e) {
      GlobalLogger().e(e.toString());
      _connected = false;
      GlobalLogger().e('WebSocket $_storedHostAddress error: $e');
    }
  }

  void _reconnectToSocket() {
    _isAttaching = true;
    Timer(Duration(milliseconds: Constants.gatewayResponseDelay), () {
      _isAttaching = false;
    });

    txSocket.close();
    // Delay to allow connection
    Timer(const Duration(seconds: 1), () {
      if (_storedCredentialConfig != null) {
        connectWithCredential(_storedCredentialConfig!);
      } else if (_storedTokenConfig != null) {
        connectWithToken(_storedTokenConfig!);
      }
    });
  }

  /// The current instance of [Call] associated with this client. Can be used
  /// to call call related functions such as hold/mute
  Call? _call;

  // Public getter to lazily initialize and return the value.
  @Deprecated(
    'telnyxClient.call is deprecated, use telnyxClient.invite() or  telnyxClient.accept()',
  )

  /// The current instance of [Call] associated with this client. Can be used
  Call get call {
    // If _call is null, initialize it with the default value.
    _call ??= _createCall();
    return _call!;
  }

  void _callEnded() {
    GlobalLogger().i('Call Ended');
    _call = null;
  }

  /// Creates an instance of [Call] that can be used to create invitations or
  /// perform common call related functions such as ending the call or placing
  /// yourself on hold/mute.
  Call _createCall() {
    // Create a placeholder for the CallHandler
    late CallHandler callHandler;

    // Create the Call object
    _call = Call(
      txSocket,
      this,
      sessid,
      _ringtonePath,
      _ringBackpath,
      callHandler = CallHandler(
        (state) {
          GlobalLogger()
              .i('Call state not overridden :Call State Changed to $state');
        },
        null,
      ),
      // Pass null initially
      _callEnded,
      _debug,
    );

    // Set the call property of CallHandler
    callHandler.call = _call!;

    return _call!;
  }

  /// Uses the provided [config] to send a credential login message to the Telnyx backend.
  /// If successful, the gateway registration process will start.
  ///
  /// May return a [TelnyxSocketError] in the case of an authentication error
  @Deprecated('Use connectWithCredential(..) instead')
  void credentialLogin(CredentialConfig config) {
    _storedCredentialConfig = config;
    final uuid = const Uuid().v4();
    final user = config.sipUser;
    final password = config.sipPassword;
    final fcmToken = config.notificationToken;
    _ringBackpath = config.ringbackPath ?? '';
    _ringtonePath = config.ringTonePath ?? '';
    _debug = config.debug;
    UserVariables? notificationParams;
    _autoReconnectLogin = config.autoReconnect ?? true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      notificationParams = UserVariables(
        pushDeviceToken: fcmToken,
        pushNotificationProvider: 'android',
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      notificationParams = UserVariables(
        pushDeviceToken: fcmToken,
        pushNotificationProvider: 'ios',
      );
    }

    final loginParams = LoginParams(
      login: user,
      passwd: password,
      loginParams: [],
      sessionId: sessid,
      userVariables: notificationParams,
      attachCall: 'true',
    );
    final loginMessage = LoginMessage(
      id: uuid,
      method: SocketMethod.login,
      params: loginParams,
      jsonrpc: JsonRPCConstant.jsonrpc,
    );

    final String jsonLoginMessage = jsonEncode(loginMessage);
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
  @Deprecated('Use connectWithToken(..) instead')
  void tokenLogin(TokenConfig config) {
    _storedTokenConfig = config;
    final uuid = const Uuid().v4();
    final token = config.sipToken;
    final fcmToken = config.notificationToken;
    _ringBackpath = config.ringbackPath ?? '';
    _ringtonePath = config.ringTonePath ?? '';
    _debug = config.debug;
    UserVariables? notificationParams;
    _autoReconnectLogin = config.autoReconnect ?? true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      notificationParams = UserVariables(
        pushDeviceToken: fcmToken,
        pushNotificationProvider: 'android',
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      notificationParams = UserVariables(
        pushDeviceToken: fcmToken,
        pushNotificationProvider: 'ios',
      );
    }

    final loginParams = LoginParams(
      loginToken: token,
      loginParams: [],
      userVariables: notificationParams,
      sessionId: sessid,
      attachCall: 'true',
    );
    final loginMessage = LoginMessage(
      id: uuid,
      method: SocketMethod.login,
      params: loginParams,
      jsonrpc: JsonRPCConstant.jsonrpc,
    );

    final String jsonLoginMessage = jsonEncode(loginMessage);
    GlobalLogger().i('Token Login Message $jsonLoginMessage');
    if (isConnected()) {
      txSocket.send(jsonLoginMessage);
    } else {
      _connectWithCallBack(null, () {
        txSocket.send(jsonLoginMessage);
      });
    }
  }

  /// Disables push notifications for the current previously authenticated user - either by [CredentialConfig] or [TokenConfig]
  /// returns : {"jsonrpc":"2.0","id":"","result":{"message":"disable push notification success"}}
  ///
  void disablePushNotifications() {
    final config = _storedCredentialConfig ?? _storedTokenConfig;
    if (config != null && config.notificationToken != null) {
      final uuid = const Uuid().v4();
      final disablePushParams = DisablePushParams(
        user: config is CredentialConfig ? config.sipUser : null,
        loginToken: config is TokenConfig ? config.sipToken : null,
        userVariables: PushUserVariables(
          pushNotificationToken: config.notificationToken!,
          pushNotificationProvider:
              defaultTargetPlatform == TargetPlatform.android
                  ? 'android'
                  : 'ios',
        ),
      );
      final disablePushMessage = DisablePushMessage(
        id: uuid,
        method: SocketMethod.disablePush,
        params: disablePushParams,
        jsonrpc: JsonRPCConstant.jsonrpc,
      );

      final String jsonDisablePushMessage = jsonEncode(disablePushMessage);
      txSocket.send(jsonDisablePushMessage);
    } else {
      GlobalLogger().e(
        'No user or associated notification token found - we cannot disable push notifications',
      );
    }
  }

  /// Creates an invitation to send to a [destinationNumber] or SIP Destination
  /// using the provided [callerName], [callerNumber] and a [clientState]
  Call newInvite(
    String callerName,
    String callerNumber,
    String destinationNumber,
    String clientState, {
    Map<String, String> customHeaders = const {},
  }) {
    final Call inviteCall = _createCall()
      ..sessionCallerName = callerName
      ..sessionCallerNumber = callerNumber
      ..sessionDestinationNumber = destinationNumber
      ..sessionClientState = clientState;
    customHeaders = customHeaders;
    inviteCall.callId = const Uuid().v4();
    final base64State = base64.encode(utf8.encode(clientState));
    updateCall(inviteCall);

    inviteCall.peerConnection = Peer(inviteCall.txSocket, _debug, this);
    inviteCall.peerConnection?.invite(
      callerName,
      callerNumber,
      destinationNumber,
      base64State,
      inviteCall.callId!,
      inviteCall.sessid,
      customHeaders,
    );

    //play ringback tone
    inviteCall.playAudio(_ringBackpath);
    inviteCall.callHandler.changeState(CallState.newCall);
    return inviteCall;
  }

  /// Accepts the incoming call specified via the [invite] parameter, sending
  /// your local specified [callerName], [callerNumber] and [clientState]
  Call acceptCall(
    IncomingInviteParams invite,
    String callerName,
    String callerNumber,
    String clientState, {
    bool isAttach = false,
    Map<String, String> customHeaders = const {},
  }) {
    final Call answerCall = getCallOrNull(invite.callID!) ?? _createCall()
      ..callId = invite.callID
      ..sessionCallerName = callerName
      ..sessionCallerNumber = callerNumber
      ..callState = CallState.connecting
      ..sessionDestinationNumber = invite.callerIdNumber ?? '-1'
      ..sessionClientState = clientState;

    final destinationNum = invite.callerIdNumber;

    answerCall.peerConnection = Peer(txSocket, _debug, this);
    answerCall.peerConnection?.accept(
      callerName,
      callerNumber,
      destinationNum!,
      clientState,
      answerCall.callId!,
      invite,
      customHeaders,
      isAttach,
    );
    answerCall.callHandler.changeState(CallState.connecting);
    answerCall.stopAudio();
    if (answerCall.callId != null) {
      updateCall(answerCall);
    }
    clearPushMetaData();
    return answerCall;
  }

  /// Provides the current [Call] instance associated with the [callId] otherwise returns null
  Call? getCallOrNull(String callId) {
    if (calls.containsKey(callId)) {
      GlobalLogger().d('Invite Call found');
      return calls[callId];
    }
    GlobalLogger().d('Invite Call not found');
    return null;
  }

  /// Update the [Call] instance associated with the [callId]
  void updateCall(Call call) {
    if (calls.containsKey(call.callId)) {
      calls[call.callId!] = call;
    } else {
      calls[call.callId!] = call;
    }
  }

  /// Closes the socket connection, effectively logging the user out.
  void disconnectWithCallBack(OnCloseCallback? closeCallback) {
    _invalidateGatewayResponseTimer();
    _resetGatewayCounters();
    clearPushMetaData();
    GlobalLogger().i('disconnect()');
    if (_closed) {
      GlobalLogger().i('WebSocket is already closed');
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
      GlobalLogger().e('close() | error closing the WebSocket: $error');
    }
  }

  /// Closes the socket connection, effectively logging the user out.
  void disconnect() {
    _invalidateGatewayResponseTimer();
    _resetGatewayCounters();
    clearPushMetaData();
    GlobalLogger().i('disconnect()');
    if (_closed) return;
    // Don't wait for the WebSocket 'close' event, do it now.
    _closed = true;
    _connected = false;
    _registered = false;
    _onClose(true, 0, 'Client send disconnect');
    try {
      txSocket.close();
    } catch (error) {
      GlobalLogger().e('close() | error closing the WebSocket: $error');
    }
  }

  /// WebSocket Event Handlers
  void _onOpen() {
    GlobalLogger().i('TelnyxClient._onOpen: WebSocket connected event triggered.');
  }

  void _onClose(bool wasClean, int code, String reason) {
    GlobalLogger().i('WebSocket closed');
    if (wasClean == false) {
      GlobalLogger().i('WebSocket abrupt disconnection');
    }
  }

  void _onMessage(dynamic data) async {
    GlobalLogger().i('TelnyxClient._onMessage: RAW WebSocket data received: ${data?.toString()?.trim()}');

    if (data != null) {
      if (data.toString().trim().isNotEmpty) {
        GlobalLogger()
            .i('Received WebSocket message :: ${data.toString().trim()}');
        if (data.toString().trim().contains('error')) {
          final errorJson = jsonEncode(data.toString());
          _logger.log(
            LogLevel.info,
            'Received WebSocket message - Contains Error :: $errorJson',
          );
          try {
            final ReceivedResult errorResult =
                ReceivedResult.fromJson(jsonDecode(data.toString()));
            onSocketErrorReceived.call(errorResult.error!);
          } on Exception catch (e) {
            GlobalLogger().e('Error parsing JSON: $e');
          }
        }

        //Login success
        if (data.toString().trim().contains('result')) {
          final paramJson = jsonEncode(data.toString());
          _logger.log(
            LogLevel.info,
            'Received WebSocket message - Contains Result :: $paramJson',
          );

          try {
            final ReceivedResult stateMessage =
                ReceivedResult.fromJson(jsonDecode(data.toString()));

            final mainMessage = ReceivedMessage(
              jsonrpc: stateMessage.jsonrpc,
              method: SocketMethod.gatewayState,
              stateParams: stateMessage.resultParams?.stateParams,
            );

            if (stateMessage.resultParams != null) {
              switch (stateMessage.resultParams?.stateParams?.state) {
                case GatewayState.reged:
                  {
                    if (!_registered) {
                      GlobalLogger().i(
                        'GATEWAY REGISTERED :: ${stateMessage.toString()}',
                      );
                      _invalidateGatewayResponseTimer();
                      _resetGatewayCounters();
                      gatewayState = GatewayState.reged;
                      _waitingForReg = false;
                      final message = TelnyxMessage(
                        socketMethod: SocketMethod.clientReady,
                        message: mainMessage,
                      );
                      onSocketMessageReceived.call(message);
                      if (_isCallFromPush) {
                        //sending attach Call
                        final String platform =
                            defaultTargetPlatform == TargetPlatform.android
                                ? 'android'
                                : 'ios';
                        const String pushEnvironment =
                            kDebugMode ? 'development' : 'production';
                        final AttachCallMessage attachCallMessage =
                            AttachCallMessage(
                          method: SocketMethod.attachCall,
                          id: const Uuid().v4(),
                          params: Params(
                            userVariables: <dynamic, dynamic>{
                              'push_notification_environment': pushEnvironment,
                              'push_notification_provider': platform,
                            },
                          ),
                          jsonrpc: '2.0',
                        );
                        GlobalLogger().i(
                          'attachCallMessage :: ${attachCallMessage.toJson()}',
                        );
                        txSocket.send(jsonEncode(attachCallMessage));
                        _isCallFromPush = false;
                        _pushMetaData = null;
                        clearPushMetaData();
                      }
                      _registered = true;
                    }
                    break;
                  }
                case GatewayState.failed:
                  {
                    GlobalLogger().i(
                      'GATEWAY REGISTRATION FAILED :: ${stateMessage.toString()}',
                    );
                    gatewayState = GatewayState.failed;
                    _invalidateGatewayResponseTimer();
                    final error = TelnyxSocketError(
                      errorCode: TelnyxErrorConstants.gatewayFailedErrorCode,
                      errorMessage: TelnyxErrorConstants.gatewayFailedError,
                    );
                    onSocketErrorReceived(error);
                    break;
                  }
                case GatewayState.unreged:
                  {
                    GlobalLogger()
                        .i('GATEWAY UNREGED :: ${stateMessage.toString()}');
                    gatewayState = GatewayState.unreged;
                    break;
                  }
                case GatewayState.register:
                  {
                    _logger.log(
                      LogLevel.info,
                      'GATEWAY REGISTERING :: ${stateMessage.toString()}',
                    );
                    gatewayState = GatewayState.register;
                    break;
                  }
                case GatewayState.unregister:
                  {
                    GlobalLogger().i(
                      'GATEWAY UNREGISTERED :: ${stateMessage.toString()}',
                    );
                    gatewayState = GatewayState.unregister;
                    break;
                  }
                case GatewayState.attached:
                  {
                    GlobalLogger()
                        .i('GATEWAY ATTACHED :: ${stateMessage.toString()}');
                    break;
                  }
                default:
                  {
                    GlobalLogger().i(
                      '$stateMessage',
                    );
                  }
              }
            }
          } on Exception catch (e) {
            GlobalLogger().e('Error parsing JSON: $e');
          }
        } else if (data.toString().trim().contains('method')) {
          //Received Telnyx Method Message
          final messageJson = jsonDecode(data.toString());

          final ReceivedMessage clientReadyMessage =
              ReceivedMessage.fromJson(jsonDecode(data.toString()));
          if (clientReadyMessage.voiceSdkId != null) {
            GlobalLogger().i('VoiceSdkID :: ${clientReadyMessage.voiceSdkId}');
            _pushMetaData = PushMetaData(
              callerNumber: null,
              callerName: null,
              voiceSdkId: clientReadyMessage.voiceSdkId,
            );
          } else {
            GlobalLogger().e('VoiceSdkID not found');
          }
          GlobalLogger().i(
            'Received WebSocket message - Contains Method :: $messageJson',
          );
          switch (messageJson['method']) {
            case SocketMethod.ping:
              {
                final result = Result(message: 'PONG', sessid: sessid);
                final pongMessage = PongMessage(
                  jsonrpc: JsonRPCConstant.jsonrpc,
                  id: const Uuid().v4(),
                  result: result,
                );
                final String jsonPongMessage = jsonEncode(pongMessage);
                txSocket.send(jsonPongMessage);
                break;
              }
            case SocketMethod.clientReady:
              {
                if (gatewayState != GatewayState.reged) {
                  GlobalLogger().i('Retrieving Gateway state...');
                  if (_waitingForReg) {
                    _requestGatewayStatus();
                    _gatewayResponseTimer = Timer(
                        Duration(
                          milliseconds: Constants.gatewayResponseDelay,
                        ), () {
                      if (_registrationRetryCounter <
                          Constants.retryRegisterTime) {
                        if (_waitingForReg) {
                          _onMessage(data);
                        }
                        _registrationRetryCounter++;
                      } else {
                        GlobalLogger().i('GATEWAY REGISTRATION TIMEOUT');
                        final error = TelnyxSocketError(
                          errorCode:
                              TelnyxErrorConstants.gatewayTimeoutErrorCode,
                          errorMessage:
                              TelnyxErrorConstants.gatewayTimeoutError,
                        );
                        onSocketErrorReceived(error);
                      }
                    });
                  }
                } else {
                  final ReceivedMessage clientReadyMessage =
                      ReceivedMessage.fromJson(jsonDecode(data.toString()));
                  final message = TelnyxMessage(
                    socketMethod: SocketMethod.clientReady,
                    message: clientReadyMessage,
                  );
                  onSocketMessageReceived.call(message);
                }
                break;
              }
            case SocketMethod.invite:
              {
                GlobalLogger().i('INCOMING INVITATION :: $messageJson');
                final ReceivedMessage invite =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                final message = TelnyxMessage(
                  socketMethod: SocketMethod.invite,
                  message: invite,
                );

                final Call offerCall = _createCall()
                  ..callId = invite.inviteParams?.callID;
                updateCall(offerCall);

                onSocketMessageReceived.call(message);

                offerCall.callHandler.changeState(CallState.ringing);
                if (!_pendingAnswerFromPush) {
                  offerCall.playRingtone(_ringtonePath);
                  offerCall.callHandler.changeState(CallState.ringing);
                } else {
                  offerCall.acceptCall(
                    invite.inviteParams!,
                    invite.inviteParams!.calleeIdName ?? '',
                    invite.inviteParams!.callerIdNumber ?? '',
                    'State',
                  );
                  _pendingAnswerFromPush = false;
                  offerCall.callHandler.changeState(CallState.connecting);
                }
                if (_pendingDeclineFromPush) {
                  offerCall.endCall();
                  offerCall.callHandler.changeState(CallState.done);
                  _pendingDeclineFromPush = false;
                }
                break;
              }
            case SocketMethod.attach:
              {
                GlobalLogger().i('ATTACH RECEIVED :: $messageJson');
                final ReceivedMessage invite =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                final message = TelnyxMessage(
                  socketMethod: SocketMethod.attach,
                  message: invite,
                );
                //play ringtone for web
                final Call offerCall = _createCall()
                  ..callId = invite.inviteParams?.callID;
                updateCall(offerCall);

                onSocketMessageReceived.call(message);

                offerCall.acceptCall(
                  invite.inviteParams!,
                  invite.inviteParams!.calleeIdName ?? '',
                  invite.inviteParams!.callerIdNumber ?? '',
                  'State',
                  isAttach: true,
                );
                _pendingAnswerFromPush = false;
                break;
              }
            case SocketMethod.media:
              {
                GlobalLogger().i('MEDIA RECEIVED :: $messageJson');
                final ReceivedMessage mediaReceived =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                if (mediaReceived.inviteParams?.sdp != null) {
                  final Call? mediaCall =
                      calls[mediaReceived.inviteParams?.callID];
                  if (mediaCall == null) {
                    GlobalLogger()
                        .d('Error : Call  is null from Media Message');
                    _sendNoCallError();
                    return;
                  }
                  mediaCall
                      .onRemoteSessionReceived(mediaReceived.inviteParams?.sdp);
                  _earlySDP = true;
                } else {
                  GlobalLogger().d('No SDP contained within Media Message');
                }
                break;
              }
            case SocketMethod.answer:
              {
                GlobalLogger().i('INVITATION ANSWERED :: $messageJson');
                final ReceivedMessage inviteAnswer =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                final Call? answerCall =
                    calls[inviteAnswer.inviteParams?.callID];
                if (answerCall == null) {
                  GlobalLogger().d('Error : Call  is null from Answer Message');
                  _sendNoCallError();
                  return;
                }
                final message = TelnyxMessage(
                  socketMethod: SocketMethod.answer,
                  message: inviteAnswer,
                );
                answerCall.callState = CallState.active;

                updateCall(answerCall);

                if (inviteAnswer.inviteParams?.sdp != null) {
                  answerCall
                      .onRemoteSessionReceived(inviteAnswer.inviteParams?.sdp);
                  onSocketMessageReceived(message);
                } else if (_earlySDP) {
                  onSocketMessageReceived(message);
                } else {
                  GlobalLogger().d(
                    'No SDP provided for Answer or Media, cannot initialize call',
                  );
                  answerCall.endCall();
                }
                _earlySDP = false;
                answerCall.stopAudio();
                break;
              }
            case SocketMethod.bye:
              {
                GlobalLogger().i('BYE RECEIVED :: $messageJson');
                final ReceivedMessage bye =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                final Call? byeCall = calls[bye.inviteParams?.callID];
                if (byeCall == null) {
                  GlobalLogger().d('Error : Call  is null from Bye Message');
                  _sendNoCallError();
                  return;
                }
                final message =
                    TelnyxMessage(socketMethod: SocketMethod.bye, message: bye);
                onSocketMessageReceived(message);
                byeCall.stopAudio();
                byeCall.peerConnection?.closeSession();
                byeCall.stopAudio();
                calls.remove(byeCall.callId);
                break;
              }
            case SocketMethod.ringing:
              {
                GlobalLogger().i('RINGING RECEIVED :: $messageJson');
                final ReceivedMessage ringing =
                    ReceivedMessage.fromJson(jsonDecode(data.toString()));
                final Call? ringingCall = calls[ringing.inviteParams?.callID];
                if (ringingCall == null) {
                  GlobalLogger()
                      .d('Error : Call  is null from Ringing Message');
                  _sendNoCallError();
                  return;
                }

                GlobalLogger().i(
                  'Telnyx Leg ID :: ${ringing.inviteParams?.telnyxLegId.toString()}',
                );
                final message = TelnyxMessage(
                  socketMethod: SocketMethod.ringing,
                  message: ringing,
                );
                onSocketMessageReceived(message);
                break;
              }
          }
        } else {
          GlobalLogger().i('Received and ignored empty packet');
        }
      } else {
        GlobalLogger().i('Received and ignored empty packet');
      }
    }
  }

  void _sendNoCallError() {
    final error = TelnyxSocketError(
      errorCode: 404,
      errorMessage: TelnyxErrorConstants.callNotFound,
    );
    onSocketErrorReceived(error);
  }

  void _requestGatewayStatus() {
    if (_waitingForReg) {
      const uuid = Uuid();
      final gatewayRequestParams = GatewayRequestStateParams();
      final gatewayRequestMessage = GatewayRequestMessage(
        id: uuid.toString(),
        method: SocketMethod.gatewayState,
        params: gatewayRequestParams,
        jsonrpc: JsonRPCConstant.jsonrpc,
      );

      final String jsonGatewayRequestMessage =
          jsonEncode(gatewayRequestMessage);

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
    gatewayState = GatewayState.idle;
  }
}
