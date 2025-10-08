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
import 'package:telnyx_webrtc/model/verto/send/conversation_message.dart';
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

  /// AudioService instance to handle audio playback
  final audioService = AudioService();

  /// Debug mode flag to enable call quality metrics
  final bool debug;

  /// Callback function that gets invoked when the call ends
  final Function callEnded;

  /// The TxSocket instance used for sending messages to the Telnyx WebRTC server
  final TxSocket txSocket;

  /// The TelnyxClient instance used for managing calls and connections
  final TelnyxClient _txClient;

  /// Session ID for the current call
  final String sessid;

  /// The file path for the ringback audio file (audio played when calling)
  final String ringBackFile;

  /// The file path for the ringtone audio file (audio played when receiving a call)
  final String ringToneFile;

  /// The unique identifier for the call, used to track the call session
  String? callId;

  /// The Peer connection instance used for WebRTC communication
  Peer? peerConnection;

  /// Indicates whether the call is currently on hold
  bool onHold = false;

  /// Indicates whether the call is currently using speaker phone
  bool speakerPhone = false;

  /// The caller's name for the current session
  String sessionCallerName = '';

  /// The caller's number for the current session
  String sessionCallerNumber = '';

  /// The destination number for the current session
  String sessionDestinationNumber = '';

  /// The client state for the current session, used to pass custom data
  String sessionClientState = '';

  /// Custom SIP headers to be sent with the call
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

  /// Handles the remote session received from the peer connection.
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
      CallState.active => (
        CauseCode.NORMAL_CLEARING.value,
        CauseCode.NORMAL_CLEARING.name,
      ),
      CallState.connecting => (
        CauseCode.NORMAL_CLEARING.value,
        CauseCode.NORMAL_CLEARING.name,
      ),
      // When Ringing (i.e. Rejecting an incoming call), use USER_BUSY
      CallState.ringing => (
        CauseCode.USER_BUSY.value,
        CauseCode.USER_BUSY.name,
      ),
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

  /// Enables or disables the speakerphone based on the [enable] parameter
  void enableSpeakerPhone(bool enable) {
    peerConnection?.enableSpeakerPhone(enable);
    speakerPhone = enable;
    GlobalLogger().d('Speakerphone ${enable ? 'enabled' : 'disabled'}');
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

  /// Handles call quality metrics updates.
  void callQualityMetricsHandler(CallQualityMetrics metrics) {
    onCallQualityChange?.call(metrics);
  }

  /// Initializes call metrics tracking by setting the callback for call quality changes.
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

  /// AI Assistant Conversation Method.
  /// Sends a conversation message to an assistant agent.
  /// 
  /// @param message The text message to send
  /// @param base64Image Optional base64 encoded image to include with the message
  ///
  /// Note: In order to provide an image to your assistant, you need to make sure that you are using a vision-capable model.
  /// The base64Image should be a base64 encoded string of the image data.
  void sendConversationMessage(String message, {String? base64Image}) {
    final uuid = const Uuid().v4();
    final messageId = const Uuid().v4();

    // Create content list, adding text message only if it's not empty
    final List<ConversationContentData> content = [];
    if (message.isNotEmpty) {
      content.add(ConversationContentData(type: 'input_text', text: message));
    }

    // Add image content if base64Image is provided
    if (base64Image != null && base64Image.isNotEmpty) {
      // Ensure the base64 string has the proper data URL format
      String imageDataUrl = base64Image;
      if (!base64Image.startsWith('data:image/')) {
        // Default to JPEG if no format is specified
        imageDataUrl = 'data:image/jpeg;base64,$base64Image';
      }

      content.add(ConversationContentData(
        type: 'image_url',
        imageUrl: ConversationImageUrl(url: imageDataUrl),
      ));
    }

    final conversationItem = ConversationItemData(
      id: messageId,
      type: 'message',
      role: 'user',
      content: content,
    );

    final conversationParams = ConversationMessageParams(
      type: 'conversation.item.create',
      previousItemId: null,
      item: conversationItem,
    );

    final conversationMessage = ConversationMessage(
      id: uuid,
      jsonrpc: JsonRPCConstant.jsonrpc,
      method: SocketMethod.aiConversation,
      params: conversationParams,
    );

    final String jsonConversationMessage = jsonEncode(conversationMessage);
    txSocket.send(jsonConversationMessage);
  }

  /// Plays an audio file from the assets directory.
  /// Example file path for '/assets/audio/sound.wav'
  void playAudio(String filePath) {
    if (filePath.isNotEmpty) {
      audioService.playLocalFile(filePath);
    }
  }

  /// Play ringtone for only web, iOS and Android will use native audio player
  void playRingtone(String filePath) {
    if (kIsWeb && filePath.isNotEmpty) {
      audioService.playLocalFile(filePath);
      return;
    }
  }

  /// Stops the currently playing audio.
  void stopAudio() {
    audioService.stopAudio();
  }
}

/// AudioService class to handle audio playback
class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  /// Plays a local audio file from the assets directory.
  Future<void> playLocalFile(String filePath) async {
    // Ensure the file path is correct and accessible from the web directory
    await _audioPlayer.setAsset(filePath);
    await _audioPlayer.setLoopMode(LoopMode.all);
    await _audioPlayer.play();
  }

  /// Stops the currently playing audio.
  Future<void> stopAudio() async {
    // Ensure the file path is correct and accessible from the web directory
    await _audioPlayer.stop();
    await _audioPlayer.dispose();
  }
}
