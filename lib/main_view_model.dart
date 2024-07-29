import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_flutter_webrtc/service/notification_service.dart';
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
  bool _isCallFromPush = false;
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

  Call? get currentCall {
    return  _telnyxClient.calls.values.firstOrNull;
  }

  IncomingInviteParams? get incomingInvitation {
    return _incomingInvite;
  }

  void observeCurrentCall() {
    currentCall?.callHandler.onCallStateChanged = (CallState state) {
      logger.i("Call State :: $state");
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
          print("current call is Active");
          // TODO: Handle this case.
          _ongoingInvitation = false;
          _ongoingCall = true;
          break;
        case CallState.held:
          // TODO: Handle this case.
          break;
        case CallState.done:
          // TODO: Handle this case.
          break;
        case CallState.error:
          // TODO: Handle this case.
          break;
      }
    };


  }

  void observeResponses() {
    // Observe Socket Messages Received
    _telnyxClient.onSocketMessageReceived = (TelnyxMessage message) {
      switch (message.socketMethod) {
        case SocketMethod.CLIENT_READY:
          {
            _registered = true;
            break;
          }
        case SocketMethod.INVITE:
          {
            observeCurrentCall();
            _ongoingInvitation = true;
            _incomingInvite = message.message.inviteParams;
            logger.i(
                "customheaders :: ${message.message.dialogParams?.customHeaders}");
            print("invite received ::  SocketMethod.INVITE");

            break;
          }
        case SocketMethod.ANSWER:
          {
            _ongoingCall = true;
            break;
          }
        case SocketMethod.BYE:
          {
            _ongoingInvitation = false;
            _ongoingCall = false;
            break;
          }
      }
      notifyListeners();
    };

    // Observe Socket Error Messages
    _telnyxClient.onSocketErrorReceived = (TelnyxSocketError error) {
      print("Error Received :: ${error.errorCode} : ${error.errorMessage}");
      Fluttertoast.showToast(
        msg: "${error.errorCode} : ${error.errorMessage}",
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

  void connect() {
    _telnyxClient.connect();
  }

  void showNotification(IncomingInviteParams message) {

    CallKitParams callKitParams = CallKitParams(
      id: message.callID,
      nameCaller: message.callerIdName,
      appName: 'Telnyx Flutter Voice',
      avatar: 'https://i.pravatar.cc/100',
      handle: message.callerIdNumber,
      type: 0,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      duration: 30000,
      extra: {},
      headers: <String, dynamic>{'platform': 'flutter'},
      android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0955fa',
          backgroundUrl: 'https://i.pravatar.cc/500',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: "Incoming Call",
          missedCallNotificationChannelName: "Missed Call"),
    );


    FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
  }

  void handlePushNotification(PushMetaData pushMetaData,
      CredentialConfig? credentialConfig, TokenConfig? tokenConfig) {
    _telnyxClient.handlePushNotification(
        pushMetaData, credentialConfig, tokenConfig);
  }

  void disconnect() {
    _telnyxClient.disconnect();
    _registered = false;
    notifyListeners();
  }

  void login(CredentialConfig credentialConfig) {
    _localName = credentialConfig.sipCallerIDName;
    _localNumber = credentialConfig.sipCallerIDNumber;
    _telnyxClient.credentialLogin(credentialConfig);
  }

  void loginWithToken(TokenConfig tokenConfig) {
    _localName = tokenConfig.sipCallerIDName;
    _localNumber = tokenConfig.sipCallerIDNumber;
    _telnyxClient.tokenLogin(tokenConfig);
  }

  void call(String destination) {
    _telnyxClient.newInvite(
        _localName, _localNumber, destination, "Fake State",
        customHeaders: {"X-Header-1": "Value1", "X-Header-2": "Value2"});
   observeCurrentCall();
  }

  void toggleSpeakerPhone() {
    _speakerPhone = !_speakerPhone;
    currentCall?.enableSpeakerPhone(_speakerPhone);
    notifyListeners();
  }

  void accept() {

    if (_incomingInvite != null) {
       _telnyxClient.acceptCall(_incomingInvite!, _localName, _localNumber, "State");
      notifyListeners();
    } else {
      throw ArgumentError(_incomingInvite);
    }
  }

  void endCall() {
    if(!Platform.isAndroid){
      FlutterCallkitIncoming.endCall(currentCall?.callId ?? "");
    }

    currentCall?.endCall(_incomingInvite?.callID);

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
