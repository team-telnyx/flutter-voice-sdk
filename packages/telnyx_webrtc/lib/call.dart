import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';
import 'package:telnyx_webrtc/model/jsonrpc.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';

import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/send_bye_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/info_dtmf_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/modify_message_body.dart';
import 'package:telnyx_webrtc/peer/peer.dart'
    if (dart.library.html) 'package:telnyx_webrtc/peer/web/peer.dart';
import 'package:telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_webrtc/tx_socket_web.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/utils/stats/webrtc_stats_reporter.dart';
import 'package:uuid/uuid.dart';
import 'package:just_audio/just_audio.dart';

import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/gateway_state.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';

/// Callback for call state changes
typedef CallStateCallback = void Function(CallState state);

/// Callback for call quality metrics updates
typedef CallQualityChangeCallback = void Function(CallQualityMetrics metrics);

class CallHandler {
  late CallStateCallback onCallStateChanged;
  late Call? call;

  CallHandler(this.onCallStateChanged, this.call);

  void changeState(CallState state) {
    call?.callState = state;
    onCallStateChanged(state);
  }
}

/// The Call class which is used for call related methods such as hold/mute or
/// creating invitations, declining calls, etc.
class Call {
  Call(
    this.txSocket,
    this._txClient,
    this.sessid,
    this.ringToneFile,
    this.ringBackFile,
    this.callHandler,
    this.callEnded,
    this.debug,
  );

  late CallHandler callHandler;
  late CallState callState;

  final audioService = AudioService();

  final bool debug;
  final Function callEnded;
  final TxSocket txSocket;
  final TelnyxClient _txClient;
  final String sessid;
  final String ringBackFile;
  final String ringToneFile;
  String? callId;
  Peer? peerConnection;

  bool onHold = false;
  String sessionCallerName = '';
  String sessionCallerNumber = '';
  String sessionDestinationNumber = '';
  String sessionClientState = '';
  Map<String, String> customHeaders = {};
  
  /// Callback for call quality metrics updates.
  /// This will be called periodically with updated metrics when debug mode is enabled.
  ///
  /// Example usage:
  /// ```dart
  /// call.onCallQualityChange = (metrics) {
  ///   print('Call quality: ${metrics.quality}');
  ///   print('MOS: ${metrics.mos}');
  ///   print('Jitter: ${metrics.jitter * 1000} ms');
  ///   print('RTT: ${metrics.rtt * 1000} ms');
  /// };
  /// ```
  CallQualityChangeCallback? onCallQualityChange;


  /// Creates an invitation to send to a [destinationNumber] or SIP Destination
  /// using the provided [callerName], [callerNumber] and a [clientState]
  ///
  /// @param callerName The name of the caller
  /// @param callerNumber The number of the caller
  /// @param destinationNumber The number to call
  /// @param clientState Custom client state to pass with the call
  /// @param customHeaders Optional custom SIP headers
  /// @param debug Whether to enable call quality metrics (default: false)
  void newInvite(
    String callerName,
    String callerNumber,
    String destinationNumber,
    String clientState, {
    Map<String, String> customHeaders = const {},
    bool debug = false,
  }) {
    // Store the session information for later use
    sessionCallerName = callerName;
    sessionCallerNumber = callerNumber;
    sessionDestinationNumber = destinationNumber;
    sessionClientState = clientState;
    this.customHeaders = Map.from(customHeaders);
    
    // If debug is true, set up the callback in the peer connection
    if (peerConnection != null && debug) {
      final session = peerConnection!._sessions[peerConnection!._selfId];
      if (session != null) {
        session.onCallQualityChange = onCallQualityChange;
      }
    }
    
    _txClient.newInvite(
      callerName,
      callerNumber,
      destinationNumber,
      clientState,
      customHeaders: customHeaders,
    );
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
  ///
  /// @param invite The incoming invite parameters
  /// @param callerName The name of the caller
  /// @param callerNumber The number of the caller
  /// @param clientState Custom client state to pass with the call
  /// @param isAttach Whether this is an attach operation
  /// @param customHeaders Optional custom SIP headers
  /// @param debug Whether to enable call quality metrics (default: false)
  Call acceptCall(
    IncomingInviteParams invite,
    String callerName,
    String callerNumber,
    String clientState, {
    bool isAttach = false,
    Map<String, String> customHeaders = const {},
    bool debug = false,
  }) {
    // Store the session information for later use
    sessionCallerName = callerName;
    sessionCallerNumber = callerNumber;
    sessionDestinationNumber = invite.callerIdNumber ?? '';
    sessionClientState = clientState;
    this.customHeaders = Map.from(customHeaders);
    
    // If debug is true, set up the callback in the peer connection
    if (peerConnection != null && debug) {
      final session = peerConnection!._sessions[peerConnection!._selfId];
      if (session != null) {
        session.onCallQualityChange = onCallQualityChange;
      }
    }
    
    return _txClient.acceptCall(
      invite,
      callerName,
      callerNumber,
      clientState,
      customHeaders: customHeaders,
      isAttach: isAttach,
      debug: debug,
    );
  }

  /// Attempts to end the call identified via the [callID]
  void endCall() {
    final uuid = const Uuid().v4();
    final byeDialogParams = ByeDialogParams(callId: callId);

    final byeParams = SendByeParams(
      cause: CauseCode.USER_BUSY.name,
      causeCode: CauseCode.USER_BUSY.index + 1,
      dialogParams: byeDialogParams,
      sessid: sessid,
    );

    final byeMessage = SendByeMessage(
      id: uuid,
      jsonrpc: JsonRPCConstant.jsonrpc,
      method: SocketMethod.bye,
      params: byeParams,
    );

    final String jsonByeMessage = jsonEncode(byeMessage);

    if (_txClient.gatewayState != GatewayState.reged) {
      GlobalLogger()
          .d('Session end gateway not  registered ${_txClient.gatewayState}');
      return;
    } else {
      GlobalLogger().d('Session end peer connection null');
    }

    txSocket.send(jsonByeMessage);
    if (peerConnection != null) {
      peerConnection?.closeSession();
    } else {
      GlobalLogger().d('Session end peer connection null');
    }
    stopAudio();
    callHandler.changeState(CallState.done);
    callEnded();
    
    // Cancel any reconnection timer for this call
    _txClient.onCallStateChangedToActive(callId);
    
    _txClient.calls.remove(callId);
    final message = TelnyxMessage(
      socketMethod: SocketMethod.bye,
      message: ReceivedMessage(method: 'telnyx_rtc.bye'),
    );
    _txClient.onSocketMessageReceived.call(message);
  }

  /// Sends a DTMF message with the chosen [tone] to the call
  /// specified via the [callID]
  void dtmf(String tone) {
    final uuid = const Uuid().v4();
    final dialogParams = DialogParams(
      attach: false,
      audio: true,
      callID: callId,
      callerIdName: sessionCallerName,
      callerIdNumber: sessionCallerNumber,
      clientState: sessionClientState,
      destinationNumber: sessionDestinationNumber,
      remoteCallerIdName: '',
      screenShare: false,
      useStereo: false,
      userVariables: [],
      video: false,
    );

    final infoParams =
        InfoParams(dialogParams: dialogParams, dtmf: tone, sessid: sessid);

    final dtmfMessageBody = DtmfInfoMessage(
      id: uuid,
      jsonrpc: JsonRPCConstant.jsonrpc,
      method: SocketMethod.info,
      params: infoParams,
    );

    final String jsonDtmfMessage = jsonEncode(dtmfMessageBody);
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
      _sendHoldModifier('unhold');
      onHold = false;
      callHandler.changeState(CallState.active);
    } else {
      _sendHoldModifier('hold');
      onHold = true;
      callHandler.changeState(CallState.held);
    }
  }

  void _sendHoldModifier(String action) {
    final uuid = const Uuid().v4();
    final dialogParams = DialogParams(
      attach: false,
      audio: true,
      callID: callId,
      callerIdName: sessionCallerName,
      callerIdNumber: sessionCallerNumber,
      clientState: sessionClientState,
      destinationNumber: sessionDestinationNumber,
      remoteCallerIdName: '',
      screenShare: false,
      useStereo: false,
      userVariables: [],
      video: false,
    );

    final modifyParams = ModifyParams(
      action: action,
      dialogParams: dialogParams,
      sessid: sessid,
    );

    final modifyMessage = ModifyMessage(
      id: uuid.toString(),
      method: SocketMethod.modify,
      params: modifyParams,
      jsonrpc: JsonRPCConstant.jsonrpc,
    );

    final String jsonModifyMessage = jsonEncode(modifyMessage);
    txSocket.send(jsonModifyMessage);
  }

  // Example file path for 'web/assets/audio/sound.wav'
  void playAudio(String filePath) {
    if (filePath.isNotEmpty) {
      audioService.playLocalFile(filePath);
    }
  }

  // Play ringtone for only web, iOS and Android will use native audio player
  void playRingtone(String filePath) {
    if (kIsWeb && filePath.isNotEmpty) {
      audioService.playLocalFile(filePath);
      return;
    }
  }

  void stopAudio() {
    audioService.stopAudio();
  }
}

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> playLocalFile(String filePath) async {
    // Ensure the file path is correct and accessible from the web directory
    await _audioPlayer.setAsset(filePath);
    await _audioPlayer.setLoopMode(LoopMode.all);
    await _audioPlayer.play();
  }

  Future<void> stopAudio() async {
    // Ensure the file path is correct and accessible from the web directory
    await _audioPlayer.stop();
    await _audioPlayer.dispose();
  }
}
