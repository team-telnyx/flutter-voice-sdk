import 'package:flutter/foundation.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/call.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/telnyx_message.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/telnyx_client.dart';
import 'package:logger/logger.dart';

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
        .newInvite("Oliverz", "+353877189671", destination, "Fake State");
  }

  void accept() {
    _telnyxClient.createCall().acceptCall(
        _telnyxClient.getInvite(), "callerName", "+353877189671", "Fake State");
    _ongoingInvitation = false;
    _ongoingCall = true;
    notifyListeners();
  }

  void endCall() {
    if (_ongoingCall) {
      _telnyxClient.call.endCall(_telnyxClient.call.callId);
    } else {
      _telnyxClient.createCall().endCall(_telnyxClient.call.callId);
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
