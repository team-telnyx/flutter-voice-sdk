import 'package:flutter/foundation.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/call.dart';

class MainViewModel with ChangeNotifier {
  final logger = Logger();
  final TelnyxClient _telnyxClient = TelnyxClient();

  bool _registered = false;
  bool _ongoingInvitation = false;
  bool _ongoingCall = false;
  IncomingInviteParams? _incomingInvite;

  bool get registered {
    return _registered;
  }

  bool get ongoingInvitation {
    return _ongoingInvitation;
  }

  bool get ongoingCall {
    return _ongoingCall;
  }

  Call get currentCall {
    return _telnyxClient.call;
  }

  IncomingInviteParams? get incomingInvitation {
    return _incomingInvite;
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
            _ongoingInvitation = true;
            _incomingInvite = message.message.inviteParams;
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
    _telnyxClient.connect("wss://rtc.telnyx.com:443");
  }

  void login(CredentialConfig credentialConfig) {
    _telnyxClient.credentialLogin(credentialConfig);
  }

  void call(String destination) {
    _telnyxClient
        .createCall()
        .newInvite("callerName", "Fake Number", destination, "Fake State");
  }

  void accept() {
    if (_incomingInvite != null) {
      _telnyxClient.createCall().acceptCall(
          _incomingInvite!, "callerName", "Fake Number", "Fake State");
      _ongoingInvitation = false;
      _ongoingCall = true;
      notifyListeners();
    } else {
      throw ArgumentError(_incomingInvite);
    }
  }

  void endCall() {
    if (_ongoingCall) {
      _telnyxClient.call.endCall(_telnyxClient.call.callId);
    } else {
      _telnyxClient.createCall().endCall(_incomingInvite?.callID);
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
