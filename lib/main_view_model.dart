import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/telnyx_client.dart';
import 'package:logger/logger.dart';

class MainViewModel with ChangeNotifier {
  final logger = Logger();
  final TelnyxClient _telnyxClient = TelnyxClient();

  bool _registered = false;
  bool _ongoingInvitation = false;

  bool get registered {
    return _registered;
  }

  bool get ongoingInvitation {
    return _ongoingInvitation;
  }

  void observeResponses() {
    _telnyxClient.onSocketMessageReceived = (String method) {
      switch (method) {
        case SocketMethod.CLIENT_READY:
          {
            _registered = true;
            break;
          }
        case SocketMethod.INVITE:
          {
            _ongoingInvitation = true;
            break;
          }
        case SocketMethod.BYE:
          {
            _ongoingInvitation = false;
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
}
