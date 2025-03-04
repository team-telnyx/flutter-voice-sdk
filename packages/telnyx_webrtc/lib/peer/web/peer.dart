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
import 'package:uuid/uuid.dart';

class Peer {
  Peer(this._socket, this._debug, this._txClient);

  final TxSocket _socket;
  final TelnyxClient _txClient;
  final bool _debug;

  /// Random numeric ID for this peer (like the mobile version).
  final String _selfId = randomNumeric(6);

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

  String get sdpSemantics =>
      WebRTC.platformIsWindows ? 'plan-b' : 'unified-plan';

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'urls': [
          DefaultConfig.defaultStun,
          DefaultConfig.defaultTurn,
        ],
        'username': DefaultConfig.username,
        'credential': DefaultConfig.password,
      },
    ],
  };

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': false,
    },
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

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

  void muteUnmuteMic() {
    if (_localStream != null) {
      final bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
    } else {
      GlobalLogger().d('Peer :: No local stream :: Unable to Mute / Unmute');
    }
  }

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
      GlobalLogger().d('Peer :: No local stream :: Unable to toggle speaker mode');
    }
  }

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
      final description =
          await session.peerConnection!.createOffer(_dcConstraints);
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
      Timer(const Duration(milliseconds: 500), () {
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
          userAgent: 'Flutter-1.0',
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
  void remoteSessionReceived(String sdp) async {
    final session = _sessions[_selfId];
    if (session != null) {
      await session.peerConnection
          ?.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    }
  }

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
    await session.peerConnection
        ?.setRemoteDescription(RTCSessionDescription(invite.sdp, 'offer'));

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
        final currentCall = _txClient.calls[callId];

        // Example skipping logic from mobile:
        if (candidate.candidate != null) {
          if (!candidate.candidate!.contains('127.0.0.1') ||
              currentCall?.callState != CallState.active) {
            GlobalLogger().i('Peer :: Add Ice Candidate => ${candidate.candidate}');
            await session.peerConnection?.addCandidate(candidate);
          } else {
            GlobalLogger().i('Peer :: Local candidate skipped: ${candidate.candidate}');
          }
        } else {
          GlobalLogger().i('Peer :: onIceCandidate: complete');
        }
      };

      // Create and set local description
      final description =
          await session.peerConnection!.createAnswer(_dcConstraints);
      await session.peerConnection!.setLocalDescription(description);

      // Give localDescription a moment to be set
      await Future.delayed(const Duration(milliseconds: 500));

      String? sdpUsed = '';
      final localDesc = await session.peerConnection?.getLocalDescription();
      if (localDesc != null) {
        sdpUsed = localDesc.sdp;
      }

      // Send ANSWER or ATTACH
      Timer(const Duration(milliseconds: 500), () {
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
          sessid: session.sid, // We use the session’s sid
          userAgent: 'Flutter-1.0',
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

  Future<MediaStream> createStream(String media) async {
    GlobalLogger().i('Peer :: Creating stream');
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false,
    };
    final MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);

    onLocalStream?.call(stream);
    return stream;
  }

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
    GlobalLogger().i('Web Peer :: _createSession => sid=$sessionId, callId=$callId');

    final newSession = session ?? Session(sid: sessionId, pid: peerId);
    if (media != 'data') {
      _localStream = await createStream(media);
      // Set up local renderer (web-only)
      await initRenderers();
      _localRenderer.srcObject = _localStream;
    }

    // Create PeerConnection
    final pc = await createPeerConnection(
      {
        ..._iceServers,
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
        final currentCall = _txClient.calls[callId];
        if (candidate.candidate != null) {
          // Example skipping local candidate if call is active and it's 127.0.0.1
          if (!candidate.candidate!.contains('127.0.0.1') ||
              currentCall?.callState != CallState.active) {
            GlobalLogger().i('Peer :: Adding ICE candidate => ${candidate.candidate}');
            await pc.addCandidate(candidate);
          } else {
            GlobalLogger().i('Peer :: Local candidate skipped => ${candidate.candidate}');
          }
        } else {
          GlobalLogger().i('Peer :: onIceCandidate: complete');
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
    await startStats(callId, peerId, pc);

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

  Future<bool> startStats(
    String callId,
    String peerId,
    RTCPeerConnection pc,
  ) async {
    if (!_debug) {
      GlobalLogger().d('Peer :: Stats manager will NOT start; debug mode not enabled.');
      return false;
    }
    _statsManager = WebRTCStatsReporter(_socket, pc, callId, peerId);
    await _statsManager?.startStatsReporting();
    GlobalLogger().d('Peer :: Stats Manager started for callId=$callId');
    return true;
  }

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
}
