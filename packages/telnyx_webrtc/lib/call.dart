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
import 'package:uuid/uuid.dart';
import 'package:just_audio/just_audio.dart';

import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/gateway_state.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';

/// Callback for call state changes
typedef CallStateCallback = void Function(CallState state);

/// Callback for call quality metrics updates
typedef CallQualityChangeCallback = void Function(CallQualityMetrics metrics);

/// **CallHandler - Single Source of Truth for Call State Management**
/// 
/// The CallHandler class serves as the centralized state management system for all call state changes
/// within the Telnyx WebRTC SDK. It ensures consistent state transitions and guarantees that state
/// change callbacks are always triggered when the call state is modified.
/// 
/// **Key Responsibilities:**
/// - Maintains the authoritative call state for each Call instance
/// - Ensures all state changes trigger the registered callback
/// - Provides a consistent interface for state management across the SDK
/// 
/// **Usage Pattern:**
/// Instead of directly modifying `call.callState`, use `callHandler.changeState(newState)` to ensure
/// proper state management and callback execution.
/// 
/// **Access Points Throughout SDK:**
/// - `call.dart`: Used in `endCall()`, `onHoldUnholdPressed()` methods
/// - `telnyx_client.dart`: Used for new calls, connections, and call termination
/// - `peer/peer.dart`: Used when WebRTC connection becomes active
/// 
/// **Example:**
/// ```dart
/// // Correct way to change call state
/// callHandler.changeState(CallState.active);
/// 
/// // This ensures both the state is updated AND the callback is triggered
/// ```
class CallHandler {
  /// Callback function that gets invoked whenever the call state changes
  late CallStateCallback onCallStateChanged;
  
  /// Reference to the associated Call instance whose state this handler manages
  late Call? call;

  /// Creates a new CallHandler instance
  /// 
  /// @param onCallStateChanged - The callback to invoke when state changes
  /// @param call - The Call instance this handler will manage
  CallHandler(this.onCallStateChanged, this.call);

  /// **Primary State Change Method - Use This Instead of Direct Assignment**
  /// 
  /// This method is the single source of truth for all call state changes.
  /// It updates the call's state and ensures the callback is triggered.
  /// 
  /// @param state - The new CallState to transition to
  /// 
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

  /// **CallHandler Instance - Single Source of Truth for State Management**
  /// 
  /// This is the authoritative state manager for this Call instance. All call state changes
  /// MUST go through this handler to ensure proper state transitions and callback execution.
  /// 
  /// **Usage:**
  /// - Use `callHandler.changeState(newState)` instead of direct `callState` assignment
  /// - Automatically triggers registered callbacks when state changes occur
  /// - Ensures consistent state management across the entire SDK
  /// 
  /// **State Change Locations in this Class:**
  /// - `endCall()` method: Sets state to `CallState.done`
  /// - `onHoldUnholdPressed()` method: Toggles between `CallState.active` and `CallState.held`
  late CallHandler callHandler;
  
  /// **Current Call State - Managed by CallHandler**
  /// 
  /// This property holds the current state of the call. While it can be read directly,
  /// it should NEVER be modified directly. All state changes must go through the
  /// `callHandler.changeState()` method to maintain consistency.
  /// 
  /// **Important:** 
  /// - READ ONLY in practice - do not assign directly
  /// - Modified only through `callHandler.changeState()`
  /// - Represents states like: newCall, ringing, connecting, active, held, done, etc.
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
  /// 
  /// This method handles the complete call termination process and uses the CallHandler
  /// to ensure proper state management during call end.
  /// 
  /// **State Management:**
  /// - Uses `callHandler.changeState(CallState.done)` as the single source of truth
  /// - Ensures state transition callbacks are triggered
  /// - Maintains consistency with the rest of the SDK
  void endCall() {
    final uuid = const Uuid().v4();
    final byeDialogParams = ByeDialogParams(callId: callId);

    // Determine the appropriate cause code based on current call state
    final (causeCode, causeName) = switch (callState) {
      // When Active or Connecting, use NORMAL_CLEARING
      CallState.active => (CauseCode.NORMAL_CLEARING.value, CauseCode.NORMAL_CLEARING.name),
      CallState.connecting => (CauseCode.NORMAL_CLEARING.value, CauseCode.NORMAL_CLEARING.name),
      // When Ringing (i.e. Rejecting an incoming call), use USER_BUSY
      CallState.ringing => (CauseCode.USER_BUSY.value, CauseCode.USER_BUSY.name),
      // Default to NORMAL_CLEARING for other states
      _ => (CauseCode.NORMAL_CLEARING.value, CauseCode.NORMAL_CLEARING.name),
    };

    final byeParams = SendByeParams(
      cause: causeName,
      causeCode: causeCode,
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

    if (_txClient.gatewayState != GatewayState.reged &&
        _txClient.gatewayState != GatewayState.idle &&
        _txClient.gatewayState != GatewayState.attached) {
      GlobalLogger().d(
        'Session end gateway not registered ${_txClient.gatewayState}',
      );
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

    final infoParams = InfoParams(
      dialogParams: dialogParams,
      dtmf: tone,
      sessid: sessid,
    );

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
  /// 
  /// **State Management via CallHandler:**
  /// - Uses `callHandler.changeState()` as the single source of truth for state transitions
  /// - When unholding: Sets state to `CallState.active` 
  /// - When holding: Sets state to `CallState.held`
  /// - Ensures proper callback execution and consistency across the SDK
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

  void callQualityMetricsHandler(CallQualityMetrics metrics) {
    onCallQualityChange?.call(metrics);
  }

  void initCallMetrics() {
    peerConnection?.onCallQualityChange = callQualityMetricsHandler;
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
