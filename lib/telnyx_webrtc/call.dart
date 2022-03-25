import 'dart:convert';

import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/send/modify_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/peer/peer.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_flutter_webrtc/telnyx_webrtc/tx_socket_web.dart';
import 'package:uuid/uuid.dart';
import 'model/verto/receive/incoming_invitation_body.dart';

class Call {
  Call(this._txSocket, this._telnyxClient, this._sessionId);

  final TxSocket _txSocket;
  final TelnyxClient _telnyxClient;
  final String _sessionId;
  late String callId;
  late Peer peerConnection;

  bool onHold = false;
  String sessionCallerName = "";
  String sessionCallerNumber = "";
  String sessionDestinationNumber = "";
  String sessionClientState = "";

  void newInvite(String callerName, String callerNumber,
      String destinationNumber, String clientState) {
    sessionCallerName = callerName;
    sessionCallerNumber = callerNumber;
    sessionDestinationNumber = destinationNumber;
    sessionClientState = clientState;

    var inviteCallId = const Uuid().toString();
    callId = inviteCallId;

    var base64State = base64.encode(utf8.encode(clientState));

    peerConnection = Peer(_txSocket);
    peerConnection.invite("0", "audio", callerName, callerNumber,
        destinationNumber, base64State, callId, _sessionId);
  }

  void acceptCall(IncomingInvitation invite, String callerName,
      String callerNumber, String clientState) {
    var callId = invite.params?.callID;
    var destinationNum = invite.params?.calleeIdNumber;

    peerConnection = Peer(_txSocket);
    peerConnection.accept("0", "audio", callerName, callerNumber,
        destinationNum!, clientState, callId!, invite);
  }

  void onMuteUnmutePressed() {
    peerConnection.muteUnmuteMic();
  }

  void onHoldUnholdPressed(Uuid callId) {
    if (onHold) {
      _sendHoldModifier("unhold");
    } else {
      _sendHoldModifier("hold");
    }
  }

  void _sendHoldModifier(String action) {
    var uuid = const Uuid();
    var dialogParams = DialogParams(
        attach: false,
        audio: true,
        callID: callId,
        callerIdName: sessionCallerName,
        callerIdNumber: sessionCallerNumber,
        clientState: sessionClientState,
        destinationNumber: sessionDestinationNumber,
        remoteCallerIdName: "",
        screenShare: false,
        useStereo: false,
        userVariables: [],
        video: false);

    var modifyParams = ModifyParams(
        action: action, dialogParams: dialogParams, sessionId: _sessionId);

    var modifyMessage = ModifyMessage(
        id: uuid.toString(),
        method: "telnyx_rtc.modify",
        params: modifyParams,
        jsonrpc: "2.0");

    String jsonModifyMessage = jsonEncode(modifyMessage);
    _txSocket.send(jsonModifyMessage);
  }
}
