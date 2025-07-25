import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/jsonrpc.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';
import 'package:telnyx_webrtc/peer/session.dart';
import 'package:telnyx_webrtc/peer/signaling_state.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_webrtc/tx_socket_web.dart';
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
  DateTime? _lastCandidateTime;
  static const int _negotiationTimeout = 500; // 500ms timeout for negotiation
  Function()? _onNegotiationComplete;

  /// Sessions by session-id.
  final Map<String, Session> _sessions = {};

  /// Local and remote streams.
  MediaStream? _localStream;
  final List<MediaStream> _remoteStreams = <MediaStream>[];

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
  Future<void> invite(
    String callerName,
    String callerNumber,
    String destinationNumber,
    String clientState,
    String callId,
    String telnyxSessionId,
    Map<String, String> customHeaders,
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
  ) async {
    try {
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

      // Give the localDescription a moment to be set
      await Future.delayed(const Duration(milliseconds: 500));

      String? sdpUsed = '';
      final localDesc = await session.peerConnection?.getLocalDescription();
      if (localDesc != null) {
        sdpUsed = localDesc.sdp;
      }

      // Send INVITE
      Timer(const Duration(milliseconds: 500), () async {
        final userAgent = await VersionUtils.getUserAgent();
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
      onCallStateChange?.call(session, CallState.active);
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

    // Indicate the call is now active (in mobile code, we do this after answer).
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
      // ICE candidate callback (with optional skipping logic)
      session.peerConnection?.onIceCandidate = (candidate) async {
        GlobalLogger().i(
          'Web Peer :: onIceCandidate in _createAnswer received: ${candidate.candidate}',
        );
        if (candidate.candidate != null) {
          final candidateString = candidate.candidate.toString();
          final isValidCandidate =
              candidateString.contains('stun.telnyx.com') ||
              candidateString.contains('turn.telnyx.com');

          if (isValidCandidate) {
            GlobalLogger().i(
              'Web Peer :: Valid ICE candidate: $candidateString',
            );
            // Only add valid candidates and reset timer
            await session.peerConnection?.addCandidate(candidate);
            _lastCandidateTime = DateTime.now();
          } else {
            GlobalLogger().i(
              'Web Peer :: Ignoring non-STUN/TURN candidate: $candidateString',
            );
          }
        } else {
          GlobalLogger().i('Web Peer :: onIceCandidate: complete');
        }
      };

      // Create and set local description
      final description = await session.peerConnection!.createAnswer(
        _dcConstraints,
      );
      await session.peerConnection!.setLocalDescription(description);

      // Start ICE candidate gathering and wait for negotiation to complete
      _lastCandidateTime = DateTime.now();
      _setOnNegotiationComplete(() async {
        String? sdpUsed = '';
        final localDesc = await session.peerConnection?.getLocalDescription();
        if (localDesc != null) {
          sdpUsed = localDesc.sdp;
        }

        final userAgent = await VersionUtils.getUserAgent();
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
    if (media != 'data') {
      _localStream = await createStream(media);
      // Set up local renderer (web-only)
      await initRenderers();
      _localRenderer.srcObject = _localStream;
    }

    // Create PeerConnection
    final pc = await createPeerConnection({
      ..._buildIceConfiguration(),
      ...{'sdpSemantics': sdpSemantics},
    }, _dcConstraints);

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
          final candidateString = candidate.candidate.toString();
          final isValidCandidate =
              candidateString.contains('stun.telnyx.com') ||
              candidateString.contains('turn.telnyx.com');

          if (isValidCandidate) {
            GlobalLogger().i(
              'Web Peer :: Valid ICE candidate: $candidateString',
            );
            // Add valid candidates
            await pc.addCandidate(candidate);
          } else {
            GlobalLogger().i(
              'Web Peer :: Ignoring non-STUN/TURN candidate: $candidateString',
            );
          }
        } else {
          GlobalLogger().i('Web Peer :: onIceCandidate: complete');
        }
      }
      ..onIceConnectionState = (state) {
        GlobalLogger().i('Peer :: ICE Connection State => $state');
        switch (state) {
          case RTCIceConnectionState.RTCIceConnectionStateFailed:
            pc.restartIce();
            break;
          case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
            // Optionally stop stats if you want
            _statsManager?.stopStatsReporting();
            break;
          default:
            break;
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

    // Start stats if debug is enabled
    await startStats(
      callId,
      peerId,
      pc,
      onCallQualityChange: onCallQualityChange,
    );

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
    _sessions.forEach((key, sess) async {
      await sess.peerConnection?.close();
      await sess.peerConnection?.dispose();
      await sess.dc?.close();
    });
    _sessions.clear();
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
    // Close peer connection
    if (session.peerConnection != null) {
      await session.peerConnection?.close();
      await session.peerConnection?.dispose();
    }
    // Close data channel
    await session.dc?.close();
    // Stop stats
    stopStats(session.sid);
  }

  void _send(dynamic event) {
    _socket.send(event);
  }

  /// Sets a callback to be invoked when ICE negotiation is complete
  void _setOnNegotiationComplete(Function() callback) {
    _onNegotiationComplete = callback;
    _startNegotiationTimer();
  }

  /// Starts the negotiation timer that checks for ICE candidate timeout
  void _startNegotiationTimer() {
    _negotiationTimer?.cancel();
    _negotiationTimer = Timer.periodic(
      const Duration(milliseconds: _negotiationTimeout),
      (timer) {
        if (_lastCandidateTime == null) return;

        final timeSinceLastCandidate = DateTime.now()
            .difference(_lastCandidateTime!)
            .inMilliseconds;
        GlobalLogger().d(
          'Time since last candidate: ${timeSinceLastCandidate}ms',
        );

        if (timeSinceLastCandidate >= _negotiationTimeout) {
          GlobalLogger().d('Negotiation timeout reached');
          _onNegotiationComplete?.call();
          _stopNegotiationTimer();
        }
      },
    );
  }

  /// Stops and cleans up the negotiation timer
  void _stopNegotiationTimer() {
    _negotiationTimer?.cancel();
    _negotiationTimer = null;
  }

  /// Cleans up resources when the peer is no longer needed
  void _release() {
    _stopNegotiationTimer();
    if (_sessions.isNotEmpty) {
      _cleanSessions();
    }
  }
}
