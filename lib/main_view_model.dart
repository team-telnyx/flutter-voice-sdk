import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/model/call_state.dart';

class MainViewModel with ChangeNotifier {
  final logger = Logger();

  //"assets/audios/ringback.mp3"
  final TelnyxClient _telnyxClient = TelnyxClient();

  bool _registered = false;
  bool _ongoingInvitation = false;
  bool _ongoingCall = false;
  bool callFromPush = false;
  bool _speakerPhone = true;
  IncomingInviteParams? _incomingInvite;

  String _localName = '';
  String _localNumber = '';

  bool get registered {
    return _registered;
  }

  bool get ongoingInvitation {
    return _ongoingInvitation;
  }

  bool get ongoingCall {
    return _ongoingCall;
  }

  Call? _currentCall;

  Call? get currentCall {
    return _telnyxClient.calls.values.firstOrNull;
  }

  IncomingInviteParams? get incomingInvitation {
    return _incomingInvite;
  }

  void observeCurrentCall() {
    currentCall?.callHandler.onCallStateChanged = (CallState state) {
      logger.i('Call State :: $state');
      switch (state) {
        case CallState.newCall:
          // TODO: Handle this case.
          break;
        case CallState.connecting:
          // TODO: Handle this case.
          break;
        case CallState.ringing:
          // TODO: Handle this case.
          break;
        case CallState.active:
          print('current call is Active');
          logger.i('current call is Active');
          _ongoingInvitation = false;
          _ongoingCall = true;
          if (Platform.isIOS) {
            // only for iOS
            // end Call for Callkit on iOS
            FlutterCallkitIncoming.setCallConnected(_incomingInvite!.callID!);
          }

          break;
        case CallState.held:
          // TODO: Handle this case.
          break;
        case CallState.done:
          FlutterCallkitIncoming.endCall(currentCall?.callId ?? '');
          // TODO: Handle this case.
          break;
        case CallState.error:
          // TODO: Handle this case.
          break;
      }
    };
  }

  void resetCallInfo() {
    _incomingInvite = null;
    _ongoingInvitation = false;
    _ongoingCall = false;
    callFromPush = false;
    logger.i('Mainviewmodel :: Reset Call Info');
  }

  void observeResponses() {
    // Observe Socket Messages Received
    _telnyxClient
      ..onSocketMessageReceived = (TelnyxMessage message) {
        logger.i('Mainviewmodel :: observeResponses :: Socket :: $message');
        switch (message.socketMethod) {
          case SocketMethod.clientReady:
            {
              _registered = true;
              logger.i(
                  'Mainviewmodel :: observeResponses : Registered :: $_registered');
              break;
            }
          case SocketMethod.invite:
            {
              observeCurrentCall();
              _incomingInvite = message.message.inviteParams;
              if (!callFromPush) {
                // only set _ongoingInvitation if the call is not from push notification
                _ongoingInvitation = true;
                showNotification(_incomingInvite!);
              } else {
                // For early accept of call
                if (waitingForInvite) {
                  accept();
                  waitingForInvite = false;
                }
              }

              logger.i(
                'customheaders :: ${message.message.dialogParams?.customHeaders}',
              );
              print('invite received ::  SocketMethod.INVITE $callFromPush');

              break;
            }
          case SocketMethod.answer:
            {
              _ongoingCall = true;
              break;
            }
          case SocketMethod.bye:
            {
              if (Platform.isIOS) {
                if (callFromPush) {
                  _endCallFromPush(true);
                } else {
                  FlutterCallkitIncoming.endCall(
                    currentCall?.callId ?? _incomingInvite!.callID!,
                  );
                  resetCallInfo();
                }
              }
              break;
            }
        }
        notifyListeners();
      }

      // Observe Socket Error Messages
      ..onSocketErrorReceived = (TelnyxSocketError error) {
        print('Error Received :: ${error.errorCode} : ${error.errorMessage}');
        Fluttertoast.showToast(
          msg: '${error.errorCode} : ${error.errorMessage}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
        );
        switch (error.errorCode) {
          case -32000:
            {
              //Todo handle token error
              break;
            }
          case -32001:
            {
              //Todo handle credential error
              break;
            }
          case -32003:
            {
              //Todo handle gateway timeout error
              break;
            }
          case -32004:
            {
              //ToDo hande gateway failure error
              break;
            }
        }
        notifyListeners();
      };
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

  void _endCallFromPush(bool fromBye) {
    if (Platform.isIOS) {
      // end Call for Callkit on iOS
      FlutterCallkitIncoming.endCall(
        currentCall?.callId ?? _incomingInvite!.callID!,
      );
      if (!fromBye) {
        _telnyxClient.calls.values.firstOrNull?.endCall(
          _incomingInvite?.callID,
        );
      }
      // Attempt to end the call if still present and disconnect from the socket to logout - this enables us to receive further push notifications after
      if (WidgetsBinding.instance?.lifecycleState !=
          AppLifecycleState.resumed) {
        _telnyxClient.disconnect();
      }
    }
    resetCallInfo();
  }

  void disconnect() {
    _telnyxClient.disconnect();
    _registered = false;
    notifyListeners();
  }

  void login(CredentialConfig credentialConfig) async {
    _localName = credentialConfig.sipCallerIDName;
    _localNumber = credentialConfig.sipCallerIDNumber;
    _telnyxClient.connectWithCredential(credentialConfig);
  }

  void loginWithToken(TokenConfig tokenConfig) {
    _localName = tokenConfig.sipCallerIDName;
    _localNumber = tokenConfig.sipCallerIDNumber;
    _telnyxClient.connectWithToken(tokenConfig);
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
    //_currentCall?.startDebugStats();
  }

  void toggleSpeakerPhone() {
    _speakerPhone = !_speakerPhone;
    currentCall?.enableSpeakerPhone(_speakerPhone);
    notifyListeners();
  }

  bool waitingForInvite = false;

  Future<void> accept({bool acceptFromNotification = false}) async {
    if (_incomingInvite != null) {
      _currentCall = _telnyxClient.acceptCall(
        _incomingInvite!,
        _localName,
        _localNumber,
        'State',
      );

      //_currentCall?.startDebugStats();

      if (Platform.isIOS) {
        // only for iOS
        await FlutterCallkitIncoming.setCallConnected(_incomingInvite!.callID!);
      }

      // Hide if not already hidden
      if (Platform.isAndroid && !acceptFromNotification) {
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

        // Hide notfication when call is accepted
        await FlutterCallkitIncoming.hideCallkitIncoming(callKitParams);
      }
      notifyListeners();
    } else {
      waitingForInvite = true;
    }
  }

  void showNotification(IncomingInviteParams message) {
    final CallKitParams callKitParams = CallKitParams(
      id: message.callID,
      nameCaller: message.callerIdName,
      appName: 'Telnyx Flutter Voice',
      avatar: 'https://i.pravatar.cc/100',
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

    FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
  }

  void endCall({bool endfromCallScreen = false}) {
    logger.i(' Platform ::: endfromCallScreen :: $endfromCallScreen');
    if (currentCall == null) {
      logger.i('Current Call is null');
    } else {
      logger.i('Current Call is not null');
    }

    if (Platform.isIOS) {
      /* when end call from CallScreen we need to tell Callkit to end the call as well
       */
      if (endfromCallScreen && callFromPush) {
        // end Call for Callkit on iOS
        _endCallFromPush(false);
        logger.i('end Call: CallfromPush $callFromPush');
      } else {
        logger.i('end Call: CallfromCallScreen $callFromPush');
        // end Call normlly on iOS
        currentCall?.endCall(_incomingInvite?.callID);
      }
    } else if (Platform.isAndroid || kIsWeb) {
      currentCall?.endCall(_incomingInvite?.callID);
    }

    _ongoingInvitation = false;
    _ongoingCall = false;
    notifyListeners();
  }

  void dtmf(String tone) {
    _telnyxClient.call.dtmf(_telnyxClient.call.callId, tone);
  }

  void muteUnmute() {
    _telnyxClient.call.onMuteUnmutePressed();
  }

  void holdUnhold() {
    _telnyxClient.call.onHoldUnholdPressed();
  }
}
