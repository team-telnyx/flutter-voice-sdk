import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/jsonrpc.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/model/verto/receive/update_media_response.dart';
import 'package:telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/modify_message_body.dart';
import 'package:telnyx_webrtc/peer/session.dart';
import 'package:telnyx_webrtc/peer/signaling_state.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_webrtc/tx_socket_web.dart';
import 'package:telnyx_webrtc/utils/codec_utils.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/utils/string_utils.dart';
import 'package:telnyx_webrtc/utils/stats/webrtc_stats_reporter.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';
import 'package:uuid/uuid.dart';

/// Represents a peer in the WebRTC communication.
class Peer {
  /// The constructor for the Peer class.
  Peer(this._socket, this._debug, this._txClient, this._forceRelayCandidate);

  final TxSocket _socket;
  final TelnyxClient _txClient;
  final bool _debug;
  final bool _forceRelayCandidate;

  /// Random numeric ID for this peer (like the mobile version).
  final String _selfId = randomNumeric(6);

  /// Add negotiation timer fields
  Timer? _negotiationTimer;

  static const int _negotiationTimeout = 300; // 300ms timeout for negotiation
  Function()? _onNegotiationComplete;

  /// Sessions by session-id.
  final Map<String, Session> _sessions = {};

  /// Current active session
  Session? currentSession;

  /// Local and remote streams.
  MediaStream? _localStream;
  final List<MediaStream> _remoteStreams = <MediaStream>[];

  /// Track previous ICE connection state for renegotiation logic
  RTCIceConnectionState? _previousIceConnectionState;

  /// Optional stats reporter (for debug).
  WebRTCStatsReporter? _statsManager;

  /// Renderers for Web
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  Function(SignalingState state)? onSignalingStateChange;
  Function(Session session, CallState state)? onCallStateChange;
  Function(MediaStream stream)? onLocalStream;
  Function(Session session, MediaStream stream)? onAddRemoteStream;
  Function(Session session, MediaStream stream)? onRemoveRemoteStream;
  Function(dynamic event)? onPeersUpdate;
  Function(Session session, RTCDataChannel dc, RTCDataChannelMessage data)?
      onDataChannelMessage;
  Function(Session session, RTCDataChannel dc)? onDataChannel;

  /// Callback for call quality metrics updates.
  CallQualityCallback? onCallQualityChange;

  /// Gets the SDP semantics based on the platform.
  /// Returns 'plan-b' for Windows and 'unified-plan' for other platforms.
  String get sdpSemantics =>
      WebRTC.platformIsWindows ? 'plan-b' : 'unified-plan';

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'urls': [DefaultConfig.defaultStun, DefaultConfig.defaultTurn],
        'username': DefaultConfig.username,
        'credential': DefaultConfig.password,
      },
    ],
  };

  /// Builds the ICE configuration based on the forceRelayCandidate setting
  Map<String, dynamic> _buildIceConfiguration() {
    final config = Map<String, dynamic>.from(_iceServers);

    if (_forceRelayCandidate) {
      // When forceRelayCandidate is enabled, only use TURN relay candidates
      config['iceTransportPolicy'] = 'relay';
      GlobalLogger().i(
        'Peer :: Force relay candidate enabled - using TURN relay only',
      );
    }

    return config;
  }

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': false},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  /// Closes all peer connections, local streams, and the socket connection.
  Future<void> close() async {
    await _cleanSessions();
    _socket.close();
  }

  /// Closes the current session (based on _selfId).
  void closeSession() {
    final session = _sessions[_selfId];
    if (session != null) {
      GlobalLogger().d('Session end success');
      _closeSession(session);
    } else {
      GlobalLogger().d('Session end failed');
    }
  }

  /// Mutes or unmutes the microphone.
  void muteUnmuteMic() {
    if (_localStream != null) {
      final bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
    } else {
      GlobalLogger().d('Peer :: No local stream :: Unable to Mute / Unmute');
    }
  }

  /// Enables or disables the speakerphone.
  /// [enable] True to enable speakerphone, false to disable.
  void enableSpeakerPhone(bool enable) {
    if (kIsWeb) {
      // On web, .enableSpeakerphone(...) is still available on recent flutter_webrtc
      GlobalLogger().d('Peer :: Speaker Enabled :: $enable');
      if (_localStream != null) {
        _localStream!.getAudioTracks()[0].enableSpeakerphone(enable);
      }
      return;
    }

    if (_localStream != null) {
      _localStream!.getAudioTracks()[0].enableSpeakerphone(enable);
      GlobalLogger().d('Peer :: Speaker Enabled :: $enable');
    } else {
      GlobalLogger().d(
        'Peer :: No local stream :: Unable to toggle speaker mode',
      );
    }
  }

  /// Initiates a new call.
  ///
  /// [callerName] The name of the caller.
  /// [callerNumber] The number of the caller.
  /// [destinationNumber] The number to call.
  /// [clientState] The client state information.
  /// [callId] The unique ID for this call.
  /// [telnyxSessionId] The Telnyx session ID.
  /// [customHeaders] Custom headers to include in the invite.
  /// [preferredCodecs] Optional list of preferred audio codecs.
  Future<void> invite(
    String callerName,
    String callerNumber,
    String destinationNumber,
    String clientState,
    String callId,
    String telnyxSessionId,
    Map<String, String> customHeaders, {
    List<Map<String, dynamic>>? preferredCodecs,
  }) async {
    final sessionId = _selfId;
    final session = await _createSession(
      null,
      peerId: Uuid().v4(),
      sessionId: sessionId,
      callId: callId,
      media: 'audio',
    );

    _sessions[sessionId] = session;

    await _createOffer(
      session,
      'audio',
      callerName,
      callerNumber,
      destinationNumber,
      clientState,
      callId,
      telnyxSessionId,
      customHeaders,
      preferredCodecs,
    );

    // Start stats collection now that local description is set
    await startStats(
      callId,
      session.pid,
      session.peerConnection!,
      onCallQualityChange: onCallQualityChange,
    );

    // Indicate a new outbound call is created
    onCallStateChange?.call(session, CallState.newCall);
  }

  Future<void> _createOffer(
    Session session,
    String media,
    String callerName,
    String callerNumber,
    String destinationNumber,
    String clientState,
    String callId,
    String telnyxSessionId,
    Map<String, String> customHeaders,
    List<Map<String, dynamic>>? preferredCodecs,
  ) async {
    try {
      // Apply codec preferences before creating offer
      if (preferredCodecs != null && preferredCodecs.isNotEmpty) {
        await applyAudioCodecPreferences(
          session.peerConnection!,
          preferredCodecs,
        );
      }

      final description = await session.peerConnection!.createOffer(
        _dcConstraints,
      );
      await session.peerConnection!.setLocalDescription(description);

      // Add any remote candidates that arrived early
      if (session.remoteCandidates.isNotEmpty) {
        for (var candidate in session.remoteCandidates) {
          if (candidate.candidate != null) {
            GlobalLogger().i('adding remote candidate: $candidate');
            await session.peerConnection?.addCandidate(candidate);
          }
        }
        session.remoteCandidates.clear();
      }

      // Start ICE candidate gathering and wait for negotiation to complete
      _setOnNegotiationComplete(() async {
        String? sdpUsed = '';
        final localDesc = await session.peerConnection?.getLocalDescription();
        if (localDesc != null) {
          sdpUsed = localDesc.sdp;
        }

        final userAgent = VersionUtils.getUserAgent();
        final dialogParams = DialogParams(
          attach: false,
          audio: true,
          callID: callId,
          callerIdName: callerName,
          callerIdNumber: callerNumber,
          clientState: clientState,
          destinationNumber: destinationNumber,
          remoteCallerIdName: '',
          screenShare: false,
          useStereo: false,
          userVariables: [],
          video: false,
          customHeaders: customHeaders,
        );

        final inviteParams = InviteParams(
          dialogParams: dialogParams,
          sdp: sdpUsed,
          sessid: session.sid,
          userAgent: userAgent,
        );

        final inviteMessage = InviteAnswerMessage(
          id: const Uuid().v4(),
          jsonrpc: JsonRPCConstant.jsonrpc,
          method: SocketMethod.invite,
          params: inviteParams,
        );

        final String jsonInviteMessage = jsonEncode(inviteMessage);
        _send(jsonInviteMessage);
      });
    } catch (e) {
      GlobalLogger().e('Peer :: _createOffer error: $e');
    }
  }

  /// Called if you receive an "answer" sdp from the server
  /// (e.g., bridging a call scenario).
  /// [sdp] The SDP string of the remote description.
  void remoteSessionReceived(String sdp) async {
    final session = _sessions[_selfId];
    if (session != null) {
      await session.peerConnection?.setRemoteDescription(
        RTCSessionDescription(sdp, 'answer'),
      );
    }
  }

  /// Accepts an incoming call.
  ///
  /// [callerName] The name of the caller.
  /// [callerNumber] The number of the caller.
  /// [destinationNumber] The destination number (usually the current user's number).
  /// [clientState] The client state information.
  /// [callId] The unique ID for this call.
  /// [invite] The incoming invite parameters containing the SDP offer.
  /// [customHeaders] Custom headers to include in the answer.
  /// [isAttach] Whether this is an attach call.
  Future<void> accept(
    String callerName,
    String callerNumber,
    String destinationNumber,
    String clientState,
    String callId,
    IncomingInviteParams invite,
    Map<String, String> customHeaders,
    bool isAttach,
  ) async {
    final sessionId = _selfId;
    final session = await _createSession(
      null,
      peerId: Uuid().v4(),
      sessionId: sessionId,
      callId: callId,
      media: 'audio',
    );

    _sessions[sessionId] = session;

    // Set the remote SDP from the inbound INVITE
    await session.peerConnection?.setRemoteDescription(
      RTCSessionDescription(invite.sdp, 'offer'),
    );

    // Create and send the Answer (or Attach)
    await _createAnswer(
      session,
      'audio',
      callerName,
      callerNumber,
      destinationNumber,
      clientState,
      callId,
      customHeaders,
      isAttach,
    );

    // Start stats collection now that descriptions are set
    await startStats(
      callId,
      session.pid,
      session.peerConnection!,
      onCallQualityChange: onCallQualityChange,
    );

    onCallStateChange?.call(session, CallState.active);
  }

  Future<void> _createAnswer(
    Session session,
    String media,
    String callerName,
    String callerNumber,
    String destinationNumber,
    String clientState,
    String callId,
    Map<String, String> customHeaders,
    bool isAttach,
  ) async {
    try {
      // ICE candidate callback
      session.peerConnection?.onIceCandidate = (candidate) async {
        GlobalLogger().i(
          'Web Peer :: onIceCandidate in _createAnswer received: ${candidate.candidate}',
        );
        if (candidate.candidate != null) {
          // Restart timer for all candidates to keep gathering active
          _restartNegotiationTimer();
        } else {
          GlobalLogger().i('Web Peer :: onIceCandidate: complete');
        }
      };

      session.peerConnection?.onIceConnectionState = (state) {
        GlobalLogger().i('Web Peer :: ICE Connection State change :: $state');
        _previousIceConnectionState = state;
        switch (state) {
          case RTCIceConnectionState.RTCIceConnectionStateConnected:
            final Call? currentCall = _txClient.calls[callId];
            currentCall?.callHandler.changeState(CallState.active);
            onCallStateChange?.call(session, CallState.active);

            // Restore speakerphone state after ICE connection is established
            // This is important for network reconnection scenarios where the call state should be preserved
            final bool shouldEnableSpeaker = currentCall?.speakerPhone ?? false;
            if (shouldEnableSpeaker) {
              Future.delayed(const Duration(milliseconds: 100), () {
                currentCall?.enableSpeakerPhone(true);
                GlobalLogger().i(
                  'Web Peer :: Restored speakerphone state in _createAnswer: enabled',
                );
              });
            }

            // Cancel any reconnection timer for this call
            _txClient.onCallStateChangedToActive(callId);
          case RTCIceConnectionState.RTCIceConnectionStateFailed:
            if (_previousIceConnectionState ==
                RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
              GlobalLogger().i(
                'Web Peer :: ICE connection failed, starting renegotiation...',
              );
              startIceRenegotiation(callId, session.sid);
              break;
            } else {
              GlobalLogger().d(
                'Web Peer :: ICE connection failed without prior disconnection, not renegotiating',
              );
              break;
            }
          case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
            _statsManager?.stopStatsReporting();
            return;
          default:
            return;
        }
      };

      // Create and set local description
      final description = await session.peerConnection!.createAnswer(
        _dcConstraints,
      );
      await session.peerConnection!.setLocalDescription(description);

      // Start ICE candidate gathering and wait for negotiation to complete
      _setOnNegotiationComplete(() async {
        String? sdpUsed = '';
        final localDesc = await session.peerConnection?.getLocalDescription();
        if (localDesc != null) {
          sdpUsed = localDesc.sdp;
        }

        final userAgent = VersionUtils.getUserAgent();
        final dialogParams = DialogParams(
          attach: false,
          audio: true,
          callID: callId,
          callerIdName: callerNumber,
          callerIdNumber: callerNumber,
          clientState: clientState,
          destinationNumber: destinationNumber,
          remoteCallerIdName: '',
          screenShare: false,
          useStereo: false,
          userVariables: [],
          video: false,
          customHeaders: customHeaders,
        );

        final inviteParams = InviteParams(
          dialogParams: dialogParams,
          sdp: sdpUsed,
          sessid: session.sid, // We use the session's sid
          userAgent: userAgent,
        );

        final answerMessage = InviteAnswerMessage(
          id: const Uuid().v4(),
          jsonrpc: JsonRPCConstant.jsonrpc,
          method: isAttach ? SocketMethod.attach : SocketMethod.answer,
          params: inviteParams,
        );

        final String jsonAnswerMessage = jsonEncode(answerMessage);
        _send(jsonAnswerMessage);
      });
    } catch (e) {
      GlobalLogger().e('Peer :: _createAnswer error: $e');
    }
  }

  /// Creates a local media stream (audio only for web).
  ///
  /// [media] The type of media to create (currently ignored, defaults to audio).
  /// Returns a [Future] that completes with the [MediaStream].
  Future<MediaStream> createStream(String media) async {
    GlobalLogger().i('Peer :: Creating stream');
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false,
    };
    final MediaStream stream = await navigator.mediaDevices.getUserMedia(
      mediaConstraints,
    );

    onLocalStream?.call(stream);
    return stream;
  }

  /// Initializes the local and remote video renderers.
  Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<Session> _createSession(
    Session? session, {
    required String peerId,
    required String sessionId,
    required String callId,
    required String media,
  }) async {
    GlobalLogger().i(
      'Web Peer :: _createSession => sid=$sessionId, callId=$callId',
    );

    final newSession = session ?? Session(sid: sessionId, pid: peerId);
    currentSession = newSession;
    if (media != 'data') {
      _localStream = await createStream(media);
      // Set up local renderer (web-only)
      await initRenderers();
      _localRenderer.srcObject = _localStream;
    }

    // Create PeerConnection
    final pc = await createPeerConnection(
      {
        ..._buildIceConfiguration(),
        ...{'sdpSemantics': sdpSemantics},
      },
      _dcConstraints,
    );

    // If we want the same plan-b/unified-plan logic as mobile:
    if (media != 'data') {
      switch (sdpSemantics) {
        case 'plan-b':
          // Plan B
          pc.onAddStream = (MediaStream stream) {
            GlobalLogger().i('Peer :: onAddStream => plan-b');
            onAddRemoteStream?.call(newSession, stream);
            _remoteStreams.add(stream);
            _remoteRenderer.srcObject = stream;
          };
          await pc.addStream(_localStream!);
          break;

        case 'unified-plan':
        default:
          // Unified Plan
          pc.onTrack = (event) {
            GlobalLogger().i(
              'Peer :: onTrack => kind=${event.track.kind}, streams=${event.streams.length}',
            );
            if (event.streams.isNotEmpty) {
              onAddRemoteStream?.call(newSession, event.streams[0]);
              _remoteStreams.add(event.streams[0]);
              _remoteRenderer.srcObject = event.streams[0];
            }
          };
          _localStream!.getTracks().forEach((track) {
            pc.addTrack(track, _localStream!);
          });
          break;
      }
    }

    // ICE callbacks
    pc
      ..onIceCandidate = (candidate) async {
        GlobalLogger().i(
          'Web Peer :: onIceCandidate in _createSession received: ${candidate.candidate}',
        );
        if (candidate.candidate != null) {
          // Restart timer for all candidates to keep gathering active
          _restartNegotiationTimer();
        } else {
          GlobalLogger().i('Web Peer :: onIceCandidate: complete');
        }
      }
      ..onIceConnectionState = (state) {
        GlobalLogger().i('Peer :: ICE Connection State change :: $state');
        _previousIceConnectionState = state;
        switch (state) {
          case RTCIceConnectionState.RTCIceConnectionStateConnected:
            final Call? currentCall = _txClient.calls[callId];
            currentCall?.callHandler.changeState(CallState.active);
            onCallStateChange?.call(newSession, CallState.active);

            // Restore speakerphone state after ICE connection is established
            // This is important for network reconnection scenarios where the call state should be preserved
            final bool shouldEnableSpeaker = currentCall?.speakerPhone ?? false;
            if (shouldEnableSpeaker) {
              Future.delayed(const Duration(milliseconds: 100), () {
                currentCall?.enableSpeakerPhone(true);
                GlobalLogger().i(
                  'Web Peer :: Restored speakerphone state: enabled',
                );
              });
            }

            // Cancel any reconnection timer for this call
            _txClient.onCallStateChangedToActive(callId);
          case RTCIceConnectionState.RTCIceConnectionStateFailed:
            if (_previousIceConnectionState ==
                RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
              GlobalLogger().i(
                'Peer :: ICE connection failed, starting renegotiation...',
              );
              startIceRenegotiation(callId, newSession.sid);
              break;
            } else {
              GlobalLogger().d(
                'Peer :: ICE connection failed without prior disconnection, not renegotiating',
              );
              break;
            }
          case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
            _statsManager?.stopStatsReporting();
            return;
          default:
            return;
        }
      }
      ..onRemoveStream = (stream) {
        GlobalLogger().i('Peer :: onRemoveStream => ${stream.id}');
        onRemoveRemoteStream?.call(newSession, stream);
        _remoteStreams.removeWhere((it) => it.id == stream.id);
      }
      ..onDataChannel = (channel) {
        _addDataChannel(newSession, channel);
      };

    newSession.peerConnection = pc;

    return newSession;
  }

  void _addDataChannel(Session session, RTCDataChannel channel) {
    channel
      ..onDataChannelState = (state) {
        GlobalLogger().i('Peer :: DataChannel State => $state');
      }
      ..onMessage = (RTCDataChannelMessage data) {
        onDataChannelMessage?.call(session, channel, data);
      };
    session.dc = channel;
    onDataChannel?.call(session, channel);
  }

  /// Starts WebRTC statistics reporting for the given call and peer connection.
  ///
  /// This only starts if debug mode is enabled.
  /// [callId] The ID of the call.
  /// [peerId] The ID of the peer.
  /// [pc] The [RTCPeerConnection] to monitor.
  /// Returns a [Future] that completes with true if stats reporting started, false otherwise.
  Future<bool> startStats(
    String callId,
    String peerId,
    RTCPeerConnection pc, {
    CallQualityCallback? onCallQualityChange,
  }) async {
    if (!_debug) {
      GlobalLogger().d(
        'Peer :: Stats manager will NOT start; debug mode not enabled.',
      );
      return false;
    }
    _statsManager = WebRTCStatsReporter(
      _socket,
      pc,
      callId,
      peerId,
      _txClient.isDebug(),
      onCallQualityChange: onCallQualityChange,
    );
    await _statsManager?.startStatsReporting();
    GlobalLogger().d('Peer :: Stats Manager started for callId=$callId');
    return true;
  }

  /// Stops WebRTC statistics reporting for the given call ID.
  /// This only acts if debug mode is enabled.
  /// [callId] The ID of the call for which to stop stats.
  void stopStats(String callId) {
    if (!_debug) return;
    _statsManager?.stopStatsReporting();
    GlobalLogger().d('Peer :: Stats Manager stopped for $callId');
  }

  Future<void> _cleanSessions() async {
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }
    _sessions
      ..forEach((key, sess) async {
        await sess.peerConnection?.close();
        await sess.peerConnection?.dispose();
        await sess.dc?.close();
      })
      ..clear();
    _statsManager?.stopStatsReporting();
  }

  Future<void> _closeSession(Session session) async {
    // Stop local stream
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }
    // Stop stats
    stopStats(session.sid);
    // Close peer connection
    if (session.peerConnection != null) {
      await session.peerConnection?.close();
      await session.peerConnection?.dispose();
    }
    // Close data channel
    await session.dc?.close();
  }

  void _send(dynamic event) {
    _socket.send(event);
  }

  /// Sets a callback to be invoked when ICE negotiation is complete
  void _setOnNegotiationComplete(Function() callback) {
    _onNegotiationComplete = callback;
    _restartNegotiationTimer();
  }

  /// Restarts the negotiation timer (Debounce pattern)
  void _restartNegotiationTimer() {
    _negotiationTimer?.cancel();
    _negotiationTimer = Timer(
      const Duration(milliseconds: _negotiationTimeout),
      () {
        GlobalLogger().d('Negotiation timeout reached');
        final callback = _onNegotiationComplete;
        _onNegotiationComplete = null; // Clear to prevent duplicate calls
        callback?.call();
        _negotiationTimer = null;
      },
    );
  }

  /// Starts ICE renegotiation process when ICE connection fails
  Future<void> startIceRenegotiation(String callId, String sessionId) async {
    try {
      GlobalLogger()
          .i('Web Peer :: Starting ICE renegotiation for call: $callId');
      if (_sessions[sessionId] != null) {
        onCallStateChange?.call(_sessions[sessionId]!, CallState.renegotiation);
        final peerConnection = _sessions[sessionId]?.peerConnection;
        if (peerConnection == null) {
          GlobalLogger().e(
            'Web Peer :: No peer connection found for session: $sessionId',
          );
          return;
        }

        // Create constraints with IceRestart flag to force ICE restart
        final constraints = {
          'mandatory': {'IceRestart': true},
          'optional': [],
        };

        // Create new offer with ICE restart enabled
        final offer = await peerConnection.createOffer(constraints);

        // Set the local description with the new local SDP
        await peerConnection.setLocalDescription(offer);

        GlobalLogger().i(
          'Web Peer :: Created new offer with ICE restart, waiting for ICE candidates...',
        );

        // Set up callback for when negotiation is complete
        _setOnNegotiationComplete(() async {
          // Get the complete SDP with ICE candidates from the peer connection
          final localDescription = await peerConnection.getLocalDescription();
          if (localDescription != null && localDescription.sdp != null) {
            _sendUpdateMediaMessage(callId, sessionId, localDescription.sdp!);
          } else {
            GlobalLogger().e(
              'Web Peer :: No local description found with ICE candidates',
            );
          }
        });
      }
    } catch (e) {
      GlobalLogger().e('Web Peer :: Error during ICE renegotiation: $e');
    }
  }

  /// Sends the updateMedia modify message with the new SDP
  void _sendUpdateMediaMessage(String callId, String sessionId, String sdp) {
    try {
      GlobalLogger()
          .i('Web Peer :: Sending updateMedia message for call: $callId');

      // Create dialog params with required callID field
      final dialogParams = DialogParams(
        callID: callId,
        customHeaders: {}, // Empty custom headers as required
      );

      final modifyMessage = ModifyMessage(
        id: const Uuid().v4(),
        jsonrpc: '2.0',
        method: 'telnyx_rtc.modify',
        params: ModifyParams(
          action: 'updateMedia',
          sessid: sessionId,
          dialogParams: dialogParams,
          sdp: sdp,
        ),
      );

      final jsonMessage = jsonEncode(modifyMessage.toJson());
      GlobalLogger().i('Web Peer :: Sending modify message: $jsonMessage');

      _socket.send(jsonMessage);
    } catch (e) {
      GlobalLogger().e('Web Peer :: Error sending updateMedia message: $e');
    }
  }

  /// Handles the updateMedia response from the server
  Future<void> handleUpdateMediaResponse(UpdateMediaResponse response) async {
    try {
      if (response.action != 'updateMedia') {
        GlobalLogger()
            .w('Web Peer :: Unexpected action in response: ${response.action}');
        return;
      }

      if (response.sdp.isEmpty) {
        GlobalLogger().e('Web Peer :: No SDP in updateMedia response');
        return;
      }

      final callId = response.callID;
      GlobalLogger()
          .i('Web Peer :: Received updateMedia response for call: $callId');

      // Find the session for this call
      final session = _sessions.values.firstWhere(
        (s) => s.sid == callId,
        orElse: () => throw Exception('Session not found for call: $callId'),
      );

      // Set the remote description to complete renegotiation
      final remoteDescription = RTCSessionDescription(response.sdp, 'answer');
      await session.peerConnection?.setRemoteDescription(remoteDescription);

      GlobalLogger().i(
        'Web Peer :: ICE renegotiation completed successfully for call: $callId',
      );
    } catch (e) {
      GlobalLogger().e('Web Peer :: Error handling updateMedia response: $e');
    }
  }

  /// Applies audio codec preferences to the peer connection's audio transceiver.
  /// This method must be called before creating an offer or answer to ensure the
  /// preferred codecs are negotiated in the correct order.
  ///
  /// [peerConnection] The RTCPeerConnection instance to apply preferences to
  /// [preferredCodecs] List of preferred audio codec maps in order of preference
  Future<void> applyAudioCodecPreferences(
    RTCPeerConnection peerConnection,
    List<Map<String, dynamic>>? preferredCodecs,
  ) async {
    if (preferredCodecs == null || preferredCodecs.isEmpty) {
      GlobalLogger().d(
        'Web Peer :: No codec preferences provided, using defaults',
      );
      return;
    }

    try {
      GlobalLogger().d(
        'Web Peer :: Attempting to apply ${preferredCodecs.length} codec preferences',
      );

      // Use CodecUtils to find the audio transceiver
      final audioTransceiver =
          await CodecUtils.findAudioTransceiver(peerConnection);

      if (audioTransceiver == null) {
        GlobalLogger().w(
          'Web Peer :: No audio transceiver found, cannot apply codec preferences',
        );
        return;
      }

      GlobalLogger().d(
        'Web Peer :: Audio transceiver found, converting codec maps to capabilities',
      );

      // Convert codec maps to capabilities
      final codecCapabilities =
          CodecUtils.convertAudioCodecMapsToCapabilities(preferredCodecs);

      if (codecCapabilities.isEmpty) {
        GlobalLogger().w(
          'Web Peer :: No valid codec capabilities created, using defaults',
        );
        return;
      }

      GlobalLogger().d(
        'Web Peer :: Applying ${codecCapabilities.length} codec capabilities to transceiver',
      );

      // Apply codec preferences to transceiver
      await audioTransceiver.setCodecPreferences(codecCapabilities);

      GlobalLogger().d(
        'Web Peer :: Successfully applied codec preferences. Order: ${codecCapabilities.map((c) => c.mimeType).toList()}',
      );
    } catch (e) {
      GlobalLogger().e(
        'Web Peer :: Error applying codec preferences: $e',
      );
    }
  }
}
