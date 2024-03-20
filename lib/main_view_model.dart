import 'package:flutter/foundation.dart';
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

class MainViewModel with ChangeNotifier {
  final logger = Logger();
  final TelnyxClient _telnyxClient = TelnyxClient();

  bool _registered = false;
  bool _ongoingInvitation = false;
  bool _ongoingCall = false;
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
    return _telnyxClient.call;
  }

  IncomingInviteParams? get incomingInvitation {
    return _incomingInvite;
  }

  void observeResponses() {
    // Observe Socket Messages Received
    _telnyxClient.onSocketMessageReceived = (TelnyxMessage message) {
      switch (message.socketMethod)
      {
        case SocketMethod.CLIENT_READY:
          {
            _registered = true;
            break;
          }
        case SocketMethod.INVITE:
          {
            _ongoingInvitation = true;
            _incomingInvite = message.message.inviteParams;
            logger.i(
                "customheaders :: ${message.message.dialogParams?.customHeaders}");
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
            FlutterCallkitIncoming.endCall(currentCall?.callId ?? "");
            break;
          }
      }
      notifyListeners();
    };

    // Observe Socket Error Messages
    _telnyxClient.onSocketErrorReceived = (TelnyxSocketError error) {
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

  void handlePushNotification(PushMetaData pushMetaData,CredentialConfig? credentialConfig,TokenConfig? tokenConfig) {
    _telnyxClient.handlePushNotification(pushMetaData, credentialConfig, tokenConfig);
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
    _telnyxClient.call.newInvite(
        _localName, _localNumber, destination, "Fake State",
        customHeaders: {"X-Header-1": "Value1", "X-Header-2": "Value2"});
  }

  void toggleSpeakerPhone() {
    _speakerPhone = !_speakerPhone;
    _telnyxClient.call.enableSpeakerPhone(_speakerPhone);
    notifyListeners();
  }

  void accept() {
    if (_incomingInvite != null) {
      _telnyxClient
          .call
          .acceptCall(_incomingInvite!, _localName, _localNumber, "Fake State");
      _ongoingInvitation = false;
      _ongoingCall = true;
      notifyListeners();
    } else {
      throw ArgumentError(_incomingInvite);
    }
  }

  void endCall() {
    FlutterCallkitIncoming.endCall(currentCall?.callId ?? "");
    if (_ongoingCall) {
      _telnyxClient.call.endCall(_telnyxClient.call.callId);
    } else {
      _telnyxClient.call.endCall(_incomingInvite?.callID);
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
