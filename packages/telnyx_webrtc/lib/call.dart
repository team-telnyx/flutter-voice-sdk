import 'dart:convert';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_webrtc/model/jsonrpc.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';

import '/model/socket_method.dart';
import '/model/verto/receive/received_message_body.dart';
import '/model/verto/send/send_bye_message_body.dart';
import '/model/verto/send/info_dtmf_message_body.dart';
import '/model/verto/send/invite_answer_message_body.dart';
import '/model/verto/send/modify_message_body.dart';
import '/peer/peer.dart' if (dart.library.html) '/web/peer.dart';
import 'package:telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_webrtc/tx_socket_web.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';

import 'model/call_state.dart';
import 'model/gateway_state.dart';
import 'model/telnyx_message.dart';

typedef CallStateCallback = void Function(CallState state);

class CallHandler {
  late CallStateCallback onCallStateChanged;

  CallHandler(this.onCallStateChanged);

  void changeState(CallState state, Call call) {
    // You can add any additional logic here before invoking the callback
    call.callState = state;
    onCallStateChanged(state);
  }
}

/// The Call class which is used for call related methods such as hold/mute or
/// creating invitations, declining calls, etc.
class Call {
  Call(this.txSocket, this._txClient, this.sessid, this.ringToneFile,
      this.ringBackFile, this.callHandler, this.callEnded);

  late CallHandler callHandler;
  late CallState callState;

  final audioService = AudioService();
  final mobileAudioPlayer = AssetsAudioPlayer.newPlayer();
  final Function callEnded;
  final TxSocket txSocket;
  final TelnyxClient _txClient;
  final String sessid;
  final String ringBackFile;
  final String ringToneFile;
  String? callId;
  Peer? peerConnection;

  bool onHold = false;
  String sessionCallerName = "";
  String sessionCallerNumber = "";
  String sessionDestinationNumber = "";
  String sessionClientState = "";
  Map<String, String> customHeaders = {};
  final _logger = Logger();

  /// Creates an invitation to send to a [destinationNumber] or SIP Destination
  /// using the provided [callerName], [callerNumber] and a [clientState]
  void newInvite(String callerName, String callerNumber,
      String destinationNumber, String clientState,
      {Map<String, String> customHeaders = const {}}) {
    _txClient.newInvite(
        callerName, callerNumber, destinationNumber, clientState,
        customHeaders: customHeaders);
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
  Call acceptCall(IncomingInviteParams invite, String callerName,
      String callerNumber, String clientState,
      {Map<String, String> customHeaders = const {}}) {
    return _txClient.acceptCall(invite, callerName, callerNumber, clientState,
        customHeaders: customHeaders);
  }

  /// Attempts to end the call identified via the [callID]
  void endCall(String? callID) {
    if (callId == null) {
      _logger.d("Call ID is null");
      return;
    }

    var uuid = const Uuid().v4();
    var byeDialogParams = ByeDialogParams(callId: callID ?? callId);

    var byeParams = SendByeParams(
        cause: CauseCode.USER_BUSY.name,
        causeCode: CauseCode.USER_BUSY.index + 1,
        dialogParams: byeDialogParams,
        sessid: sessid);

    var byeMessage = SendByeMessage(
        id: uuid,
        jsonrpc: JsonRPCConstant.jsonrpc,
        method: SocketMethod.BYE,
        params: byeParams);

    String jsonByeMessage = jsonEncode(byeMessage);

    if (_txClient.gatewayState != GatewayState.REGED) {
      _logger
          .d("Session end gateway not  registered ${_txClient.gatewayState}");
      return;
    } else {
      _logger.d("Session end peer connection null");
    }

    txSocket.send(jsonByeMessage);
    if (peerConnection != null) {
      peerConnection?.closeSession();
    } else {
      _logger.d("Session end peer connection null");
    }
    stopAudio();
    callHandler.changeState(CallState.done, this);
    callEnded();
    _txClient.calls.remove(callId);
    var message = TelnyxMessage(
        socketMethod: SocketMethod.BYE,
        message: ReceivedMessage(method: "telnyx_rtc.bye"));
    _txClient.onSocketMessageReceived.call(message);
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
        InfoParams(dialogParams: dialogParams, dtmf: tone, sessid: sessid);

    var dtmfMessageBody = DtmfInfoMessage(
        id: uuid,
        jsonrpc: JsonRPCConstant.jsonrpc,
        method: SocketMethod.INFO,
        params: infoParams);

    String jsonDtmfMessage = jsonEncode(dtmfMessageBody);
    txSocket.send(jsonDtmfMessage);
  }

  /// Either mutes or unmutes local audio based on the current mute state
  void onMuteUnmutePressed() {
    peerConnection?.muteUnmuteMic();
  }

  void enableSpeakerPhone(bool enable) {
    peerConnection?.enableSpeakerPhone(enable);
  }

  /// Either places the call on hold, or unholds the call based on the current
  /// hold state.
  void onHoldUnholdPressed() {
    if (onHold) {
      _sendHoldModifier("unhold");
      onHold = false;
      callHandler.changeState(CallState.active, this);
    } else {
      _sendHoldModifier("hold");
      onHold = true;
      callHandler.changeState(CallState.held, this);
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
        action: action, dialogParams: dialogParams, sessid: sessid);

    var modifyMessage = ModifyMessage(
        id: uuid.toString(),
        method: SocketMethod.MODIFY,
        params: modifyParams,
        jsonrpc: JsonRPCConstant.jsonrpc);

    String jsonModifyMessage = jsonEncode(modifyMessage);
    txSocket.send(jsonModifyMessage);
  }

  // Example file path for 'web/assets/audio/sound.wav'
  void playAudio(String filePath) {
    if (kIsWeb && filePath.isNotEmpty) {
      audioService.playLocalFile(filePath);
      return;
    }
    mobileAudioPlayer.open(
      Audio(filePath),
      autoStart: true,
      showNotification: false,
    );
  }

  // Play ringtone for only web, iOS and Android will use native audio player
  void playRingtone(String filePath) {
    if (kIsWeb && filePath.isNotEmpty) {
      audioService.playLocalFile(filePath);
      return;
    }
  }

  void stopAudio() {
    if (kIsWeb) {
      audioService.stopAudio();
      return;
    }
    mobileAudioPlayer.stop();
  }
}

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> playLocalFile(String filePath) async {
    // Ensure the file path is correct and accessible from the web directory
    await _audioPlayer.play(DeviceFileSource(filePath));
  }

  Future<void> stopAudio() async {
    // Ensure the file path is correct and accessible from the web directory
    _audioPlayer.stop();
    await _audioPlayer.release();
  }
}
