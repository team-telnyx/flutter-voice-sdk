import 'dart:convert';

import '/model/socket_method.dart';
import '/model/verto/receive/received_message_body.dart';
import '/model/verto/send/send_bye_message_body.dart';
import '/model/verto/send/info_dtmf_message_body.dart';
import '/model/verto/send/invite_answer_message_body.dart';
import '/model/verto/send/modify_message_body.dart';
import '/peer/peer.dart';
import '../tx_socket.dart'
    if (dart.library.js) 'package:telnyx_flutter_webrtc/telnyx_webrtc/tx_socket_web.dart';
import 'package:uuid/uuid.dart';

class Call {
  Call(this._txSocket, this._sessionId);

  final TxSocket _txSocket;
  final String _sessionId;
  late String? callId;
  Peer? peerConnection;

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

    callId = const Uuid().toString();
    var base64State = base64.encode(utf8.encode(clientState));

    peerConnection = Peer(_txSocket);
    peerConnection?.invite(callerName, callerNumber, destinationNumber,
        base64State, callId!, _sessionId);
  }

  void acceptCall(IncomingInviteParams invite, String callerName,
      String callerNumber, String clientState) {
    callId = invite.callID;

    sessionCallerName = callerName;
    sessionCallerNumber = callerNumber;
    sessionDestinationNumber = invite.callerIdName ?? "Unknown Caller";
    sessionClientState = clientState;

    var destinationNum = invite.callerIdNumber;

    peerConnection = Peer(_txSocket);
    peerConnection?.accept(callerName, callerNumber, destinationNum!,
        clientState, callId!, invite);
  }

  void endCall(String? callID) {
    var uuid = const Uuid();
    var byeDialogParams = ByeDialogParams(callId: callID);

    var byeParams = SendByeParams(
        cause: CauseCode.USER_BUSY.name,
        causeCode: CauseCode.USER_BUSY.index + 1,
        dialogParams: byeDialogParams,
        sessionId: _sessionId);

    var byeMessage = SendByeMessage(
        id: uuid.toString(),
        jsonrpc: "2.0",
        method: SocketMethod.BYE,
        params: byeParams);

    String jsonByeMessage = jsonEncode(byeMessage);
    _txSocket.send(jsonByeMessage);
    if (peerConnection != null) {
      peerConnection?.closeSession(_sessionId);
    }
  }

  void dtmf(String? callID, String tone) {
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

    var infoParams = InfoParams(
        dialogParams: dialogParams, dtmf: tone, sessionId: _sessionId);

    var dtmfMessageBody = DtmfInfoMessage(
        id: uuid.toString(),
        jsonrpc: "2.0",
        method: SocketMethod.INFO,
        params: infoParams);

    String jsonDtmfMessage = jsonEncode(dtmfMessageBody);
    _txSocket.send(jsonDtmfMessage);
  }

  void onMuteUnmutePressed() {
    peerConnection?.muteUnmuteMic();
  }

  void onHoldUnholdPressed() {
    if (onHold) {
      _sendHoldModifier("unhold");
      onHold = false;
    } else {
      _sendHoldModifier("hold");
      onHold = true;
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
        method: SocketMethod.MODIFY,
        params: modifyParams,
        jsonrpc: "2.0");

    String jsonModifyMessage = jsonEncode(modifyMessage);
    _txSocket.send(jsonModifyMessage);
  }
}
