import 'dart:convert';

import 'package:telnyx_webrtc/model/jsonrpc.dart';

import '/model/socket_method.dart';
import '/model/verto/receive/received_message_body.dart';
import '/model/verto/send/send_bye_message_body.dart';
import '/model/verto/send/info_dtmf_message_body.dart';
import '/model/verto/send/invite_answer_message_body.dart';
import '/model/verto/send/modify_message_body.dart';
import '/peer/peer.dart';
import 'package:telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_webrtc/tx_socket_web.dart';
import 'package:uuid/uuid.dart';

/// The Call class which is used for call related methods such as hold/mute or
/// creating invitations, declining calls, etc.
class Call {
  Call(this._txSocket, this._sessid);

  final TxSocket _txSocket;
  final String _sessid;
  late String? callId;
  Peer? peerConnection;

  bool onHold = false;
  String sessionCallerName = "";
  String sessionCallerNumber = "";
  String sessionDestinationNumber = "";
  String sessionClientState = "";

  /// Creates an invitation to send to a [destinationNumber] or SIP Destination
  /// using the provided [callerName], [callerNumber] and a [clientState]
  void newInvite(String callerName, String callerNumber,
      String destinationNumber, String clientState) {
    sessionCallerName = callerName;
    sessionCallerNumber = callerNumber;
    sessionDestinationNumber = destinationNumber;
    sessionClientState = clientState;

    callId = const Uuid().v4();
    var base64State = base64.encode(utf8.encode(clientState));

    peerConnection = Peer(_txSocket);
    peerConnection?.invite(callerName, callerNumber, destinationNumber,
        base64State, callId!, _sessid);
  }

  void onRemoteSessionReceived(String? sdp) {
    if (sdp != null) {
      peerConnection?.remoteSessionReceived(sdp);
    } else {
      ArgumentError(sdp);
    }
  }

  /// Accepts the incoming call specified via the [invite] parameter, sending
  /// your local specified [callerName], [callerNumber] and [clientState]
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

  /// Attempts to end the call identified via the [callID]
  void endCall(String? callID) {
    var uuid = const Uuid().v4();
    var byeDialogParams = ByeDialogParams(callId: callID);

    var byeParams = SendByeParams(
        cause: CauseCode.USER_BUSY.name,
        causeCode: CauseCode.USER_BUSY.index + 1,
        dialogParams: byeDialogParams,
        sessid: _sessid);

    var byeMessage = SendByeMessage(
        id: uuid,
        jsonrpc: JsonRPCConstant.jsonrpc,
        method: SocketMethod.BYE,
        params: byeParams);

    String jsonByeMessage = jsonEncode(byeMessage);
    _txSocket.send(jsonByeMessage);
    if (peerConnection != null) {
      peerConnection?.closeSession(_sessid);
    }
  }

  /// Sends a DTMF message with the chosen [tone] to the call
  /// specified via the [callID]
  void dtmf(String? callID, String tone) {
    var uuid = const Uuid().v4();
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

    var infoParams =
        InfoParams(dialogParams: dialogParams, dtmf: tone, sessid: _sessid);

    var dtmfMessageBody = DtmfInfoMessage(
        id: uuid,
        jsonrpc: JsonRPCConstant.jsonrpc,
        method: SocketMethod.INFO,
        params: infoParams);

    String jsonDtmfMessage = jsonEncode(dtmfMessageBody);
    _txSocket.send(jsonDtmfMessage);
  }

  /// Either mutes or unmutes local audio based on the current mute state
  void onMuteUnmutePressed() {
    peerConnection?.muteUnmuteMic();
  }

  /// Either places the call on hold, or unholds the call based on the current
  /// hold state.
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
    var uuid = const Uuid().v4();
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
        action: action, dialogParams: dialogParams, sessid: _sessid);

    var modifyMessage = ModifyMessage(
        id: uuid.toString(),
        method: SocketMethod.MODIFY,
        params: modifyParams,
        jsonrpc: JsonRPCConstant.jsonrpc);

    String jsonModifyMessage = jsonEncode(modifyMessage);
    _txSocket.send(jsonModifyMessage);
  }
}
