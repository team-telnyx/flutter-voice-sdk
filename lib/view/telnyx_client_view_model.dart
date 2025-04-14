import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_flutter_webrtc/file_logger.dart';
import 'package:telnyx_flutter_webrtc/utils/background_detector.dart';
import 'package:telnyx_flutter_webrtc/utils/custom_sdk_logger.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

enum CallStateStatus {
  disconnected,
  idle,
  ringing,
  ongoingInvitation,
  connectingToCall,
  ongoingCall,
}

class TelnyxClientViewModel with ChangeNotifier {
  final logger = Logger();
  final TelnyxClient _telnyxClient = TelnyxClient();

  bool _registered = false;
  bool _loggingIn = false;
  bool callFromPush = false;
  bool _speakerPhone = true;
  bool _mute = false;
  bool _hold = false;

  CredentialConfig? _credentialConfig;
  IncomingInviteParams? _incomingInvite;

  String _localName = '';
  String _localNumber = '';

  bool get registered {
    return _registered;
  }

  bool get loggingIn {
    return _loggingIn;
  }

  bool get speakerPhoneState {
    return _speakerPhone;
  }

  bool get muteState {
    return _mute;
  }

  bool get holdState {
    return _hold;
  }

  String get sessionId {
    return _telnyxClient.sessid;
  }

  CallStateStatus _callState = CallStateStatus.disconnected;

  CallStateStatus get callState => _callState;

  set callState(CallStateStatus newState) {
    if (newState == CallStateStatus.ongoingCall) {
      logger.i('Call ongoing');
    }
    _callState = newState;
    notifyListeners();
  }

  Call? _currentCall;

  Call? get currentCall {
    return _telnyxClient.calls.values.firstOrNull;
  }

  IncomingInviteParams? get incomingInvitation {
    return _incomingInvite;
  }

  void resetCallInfo() {
    logger.i('TxClientViewModel :: Reset Call Info');
    BackgroundDetector.ignore = false;
    _incomingInvite = null;
    _currentCall = null;
    _speakerPhone = false;
    _mute = false;
    _hold = false;
    callState = CallStateStatus.idle;
    updateCallFromPush(false);
    notifyListeners();
  }

  void updateCallFromPush(bool value) {
    callState = CallStateStatus.connectingToCall;
    callFromPush = value;
    notifyListeners();
  }

  void observeCurrentCall() {
    currentCall?.callHandler.onCallStateChanged = (CallState state) {
      logger.i('Call State :: $state');
      switch (state) {
        case CallState.newCall:
          logger.i('New Call');
          break;
        case CallState.connecting:
          logger.i('Connecting');
          _callState = CallStateStatus.connectingToCall;
          notifyListeners();
          break;
        case CallState.ringing:
          if (_callState == CallStateStatus.connectingToCall) {
            // Ringing state as a result of an invitation after a push notification reaction - ignore invitation as we should be connecting and auto answering
            return;
          }
          _callState = CallStateStatus.ongoingInvitation;
          notifyListeners();
          break;
        case CallState.active:
          logger.i('current call is Active');
          _callState = CallStateStatus.ongoingCall;
          notifyListeners();
          if (!kIsWeb && Platform.isIOS) {
            // only for iOS
            FlutterCallkitIncoming.setCallConnected(_incomingInvite!.callID!);
          }

          break;
        case CallState.held:
          logger.i('Held');
          break;
        case CallState.done:
          if (!kIsWeb) {
            FlutterCallkitIncoming.endCall(currentCall?.callId ?? '');
          }
          break;
        case CallState.error:
          logger.i('error');
          break;
        case CallState.reconnecting:
          logger.i('reconnecting - ${state.reason}');
          break;
        case CallState.dropped:
          logger.i('dropped - ${state.reason}');
          break;
      }
    };
  }

  Future<void> _saveCredentialsForAutoLogin(
    CredentialConfig credentialConfig,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sipUser', credentialConfig.sipUser);
    await prefs.setString('sipPassword', credentialConfig.sipPassword);
    await prefs.setString('sipName', credentialConfig.sipCallerIDName);
    await prefs.setString('sipNumber', credentialConfig.sipCallerIDNumber);
    if (credentialConfig.notificationToken != null) {
      await prefs.setString(
        'notificationToken',
        credentialConfig.notificationToken!,
      );
    }
  }

  Future<void> _clearCredentialsForAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sipUser');
    await prefs.remove('sipPassword');
    await prefs.remove('sipName');
    await prefs.remove('sipNumber');
    await prefs.remove('notificationToken');
  }

  void observeResponses() {
    // Observe Socket Messages Received
    _telnyxClient
      ..onSocketMessageReceived = (TelnyxMessage message) async {
        logger.i(
          'TxClientViewModel :: observeResponses :: Socket :: ${message.message}',
        );
        switch (message.socketMethod) {
          case SocketMethod.clientReady:
            {
              if (_credentialConfig != null) {
                await _saveCredentialsForAutoLogin(_credentialConfig!);
              }
              _registered = true;
              logger.i(
                'TxClientViewModel :: observeResponses : Registered :: $_registered',
              );
              _callState = CallStateStatus.idle;
              break;
            }
          case SocketMethod.invite:
            {
              callState = CallStateStatus.ongoingInvitation;
              _incomingInvite = message.message.inviteParams;
              observeCurrentCall();
              if (!callFromPush) {
                await showNotification(_incomingInvite!);
              } else {
                // For early accept of call
                if (waitingForInvite) {
                  await accept();
                  waitingForInvite = false;
                }
              }

              logger.i(
                'customheaders :: ${message.message.dialogParams?.customHeaders}',
              );

              notifyListeners();
              break;
            }
          case SocketMethod.answer:
            {
              callState = CallStateStatus.ongoingCall;
              notifyListeners();
              break;
            }
          case SocketMethod.ringing:
            {
              callState = CallStateStatus.ringing;
              notifyListeners();
              break;
            }
          case SocketMethod.bye:
            {
              callState = CallStateStatus.idle;

              if (!kIsWeb && Platform.isIOS) {
                if (callFromPush) {
                  _endCallFromPush(true);
                } else {
                  await FlutterCallkitIncoming.endCall(
                    currentCall?.callId ?? _incomingInvite!.callID!,
                  );
                  resetCallInfo();
                }
              }
              break;
            }
        }
        notifyListeners();

        if (!kIsWeb) {
          final messageLogger = await FileLogger.getInstance();
          await messageLogger.writeLog(message.toString());
        }
      }

      // Observe Socket Error Messages
      ..onSocketErrorReceived = (TelnyxSocketError error) {
        Fluttertoast.showToast(
          msg: '${error.errorCode} : ${error.errorMessage}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: telnyx_green,
          textColor: Colors.white,
        );
        switch (error.errorCode) {
          //ToDo Error handling here depends on the requirement of the SDK implementor and the use case
          case -32000:
            {
              //Todo handle token error (try again, sign user out and move to login screen, etc)
              logger.i('${error.errorMessage} :: The token is invalid or expired');
              _loggingIn = false;
              break;
            }
          case -32001:
            {
              //Todo handle credential error (try again, sign user out and move to login screen, etc)
              _loggingIn = false;
              logger.i('${error.errorMessage} :: The Credential is invalid');
              break;
            }
          case -32002:
            {
              //Todo handle codec error (end call and show error message, call back, etc)
              logger.i('${error.errorMessage} :: There was an issue with the SDP Handshake, likely due to invalid ICE Candidates');
              break;
            }
          case -32003:
            {
              //Todo handle gateway timeout error (try again, check network connection, etc)
              logger.i('${error.errorMessage} :: It is taking too long to register with the gateway');
              break;
            }
          case -32004:
            {
              //ToDo hande gateway failure error (try again, check network connection, etc)
              logger.i('${error.errorMessage} :: Registration with the gateway has failed');
              break;
            }
        }
        notifyListeners();
      };
  }

  void _endCallFromPush(bool fromBye) {
    if (!kIsWeb && Platform.isIOS) {
      // end Call for Callkit on iOS
      FlutterCallkitIncoming.endCall(
        currentCall?.callId ?? _incomingInvite!.callID!,
      );
      if (!fromBye) {
        _telnyxClient.calls.values.firstOrNull?.endCall();
      }
      // Attempt to end the call if still present and disconnect from the socket to logout - this enables us to receive further push notifications after

      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        _telnyxClient.disconnect();
      }
    }
    resetCallInfo();
  }

  void handlePushNotification(
    PushMetaData pushMetaData,
    CredentialConfig? credentialConfig,
    TokenConfig? tokenConfig,
  ) {
    _telnyxClient.handlePushNotification(
      pushMetaData,
      credentialConfig,
      tokenConfig,
    );
  }

  void disconnect() {
    _telnyxClient.disconnect();
    callState = CallStateStatus.disconnected;
    _loggingIn = false;
    _registered = false;
    notifyListeners();
  }

  void login(CredentialConfig credentialConfig) async {
    _loggingIn = true;
    notifyListeners();

    _localName = credentialConfig.sipCallerIDName;
    _localNumber = credentialConfig.sipCallerIDNumber;
    _credentialConfig = credentialConfig;
    _telnyxClient.connectWithCredential(credentialConfig);
    observeResponses();
  }

  void loginWithToken(TokenConfig tokenConfig) {
    _loggingIn = true;
    notifyListeners();

    _localName = tokenConfig.sipCallerIDName;
    _localNumber = tokenConfig.sipCallerIDNumber;
    _telnyxClient.connectWithToken(tokenConfig);
    observeResponses();
  }

  void call(String destination) {
    _currentCall = _telnyxClient.newInvite(
      _localName,
      _localNumber,
      destination,
      'Fake State',
      customHeaders: {'X-Header-1': 'Value1', 'X-Header-2': 'Value2'},
    );
    observeCurrentCall();
  }

  bool waitingForInvite = false;

  Future<Config?> getConfig() async {
    final config = await _getCredentialConfig();
    if (config != null) {
      return config;
    } else {
      return await _getTokenConfig();
    }
  }

  Future<CredentialConfig?> _getCredentialConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final sipUser = prefs.getString('sipUser');
    final sipPassword = prefs.getString('sipPassword');
    final sipName = prefs.getString('sipName');
    final sipNumber = prefs.getString('sipNumber');
    final notificationToken = prefs.getString('notificationToken');
    if (sipUser != null &&
        sipPassword != null &&
        sipName != null &&
        sipNumber != null) {
      return CredentialConfig(
        sipCallerIDName: sipName,
        sipCallerIDNumber: sipNumber,
        sipUser: sipUser,
        sipPassword: sipPassword,
        notificationToken: notificationToken,
        debug: true,
        logLevel: LogLevel.debug,
        customLogger: CustomSDKLogger(),
        reconnectionTimeout: 30000,
      );
    } else {
      return null;
    }
  }

  Future<TokenConfig?> _getTokenConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final sipName = prefs.getString('sipName');
    final sipNumber = prefs.getString('sipNumber');
    final notificationToken = prefs.getString('notificationToken');
    if (token != null && sipName != null && sipNumber != null) {
      return TokenConfig(
        sipCallerIDName: sipName,
        sipCallerIDNumber: sipNumber,
        sipToken: token,
        notificationToken: notificationToken,
        debug: true,
        logLevel: LogLevel.debug,
      );
    } else {
      return null;
    }
  }

  Future<void> accept({bool acceptFromNotification = false}) async {
    if (callState == CallStateStatus.ongoingCall) {
      return;
    }

    if (_incomingInvite != null) {
      _currentCall = _telnyxClient.acceptCall(
        _incomingInvite!,
        _localName,
        _localNumber,
        'State',
      );

      if (!kIsWeb && Platform.isIOS) {
        // only for iOS
        await FlutterCallkitIncoming.setCallConnected(_incomingInvite!.callID!);
      }

      // Hide if not already hidden
      if (!kIsWeb && Platform.isAndroid && !acceptFromNotification) {
        final CallKitParams callKitParams = CallKitParams(
          id: _incomingInvite!.callID,
          nameCaller: _incomingInvite!.callerIdName,
          appName: 'Telnyx Flutter Voice',
          avatar: 'https://i.pravatar.cc/100',
          handle: _incomingInvite!.callerIdNumber,
          type: 0,
          textAccept: 'Accept',
          textDecline: 'Decline',
          missedCallNotification: const NotificationParams(
            showNotification: false,
            isShowCallback: false,
            subtitle: 'Missed call',
          ),
          duration: 30000,
          extra: {},
          headers: <String, dynamic>{'platform': 'flutter'},
        );

        _callState = CallStateStatus.connectingToCall;
        notifyListeners();

        // Hide notification when call is accepted
        await FlutterCallkitIncoming.hideCallkitIncoming(callKitParams);
      }
      notifyListeners();
    } else {
      logger.i('Answered early, waiting for invite');
      waitingForInvite = true;
    }
    notifyListeners();
  }

  Future<void> showNotification(IncomingInviteParams message) async {
    if (kIsWeb) {
      return;
    }
    // Temporarily ignore lifecycle events during notification to avoid actions being done while app is in background and notification in foreground.
    BackgroundDetector.ignore = true;
    final CallKitParams callKitParams = CallKitParams(
      id: message.callID,
      nameCaller: message.callerIdName,
      appName: 'Telnyx Flutter Voice',
      handle: message.callerIdNumber,
      type: 0,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: false,
        isShowCallback: false,
        subtitle: 'Missed call',
      ),
      duration: 30000,
      extra: {},
      headers: <String, dynamic>{'platform': 'flutter'},
    );

    await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
  }

  void endCall({bool endfromCallScreen = false}) {
    logger.i(' Platform ::: endfromCallScreen :: $endfromCallScreen');
    if (currentCall == null) {
      logger.i('Current Call is null');
    } else {
      logger.i('Current Call is not null');
    }

    if (!kIsWeb && Platform.isIOS) {
      /* when end call from CallScreen we need to tell Callkit to end the call as well
       */
      if (endfromCallScreen && callFromPush) {
        // end Call for Callkit on iOS
        _endCallFromPush(false);
        logger.i('end Call: CallfromPush $callFromPush');
      } else {
        logger.i('end Call: CallfromCallScreen $callFromPush');
        // end Call normally on iOS
        currentCall?.endCall();
      }
    } else if (kIsWeb || Platform.isAndroid) {
      currentCall?.endCall();
    }

    _callState = CallStateStatus.idle;
    notifyListeners();
  }

  void dtmf(String tone) {
    currentCall?.dtmf(tone);
  }

  void muteUnmute() {
    _mute = !_mute;
    _currentCall?.onMuteUnmutePressed();
    notifyListeners();
  }

  void holdUnhold() {
    _hold = !_hold;
    currentCall?.onHoldUnholdPressed();
    notifyListeners();
  }

  void toggleSpeakerPhone() {
    if (kIsWeb) {
      Fluttertoast.showToast(
        msg: 'Toggling loud speaker is disabled on the web client',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: telnyx_green,
        textColor: Colors.white,
      );
      return;
    }
    _speakerPhone = !_speakerPhone;
    currentCall?.enableSpeakerPhone(_speakerPhone);
    notifyListeners();
  }

  void exportLogs() async {
    final messageLogger = await FileLogger.getInstance();
    final logContents = await messageLogger.exportLogs();
    logger.i('Log Contents :: $logContents');
    //ToDo: Implement log export
  }

  void disablePushNotifications() {
    _telnyxClient.disablePushNotifications();
  }
}
