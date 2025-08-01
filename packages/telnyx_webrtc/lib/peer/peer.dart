import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';
import 'package:telnyx_webrtc/peer/session.dart';
import 'package:telnyx_webrtc/peer/signaling_state.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/utils/stats/webrtc_stats_reporter.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';
import 'package:telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_webrtc/tx_socket_web.dart';
import 'package:telnyx_webrtc/utils/string_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/jsonrpc.dart';

/// Represents a peer in the WebRTC communication.
class Peer {
  /// The peer connection instance.
  RTCPeerConnection? peerConnection;

  /// The constructor for the Peer class.
  Peer(this._socket, this._debug, this._txClient, this._forceRelayCandidate);

  final String _selfId = randomNumeric(6);

  final TxSocket _socket;
  final TelnyxClient _txClient;
  final bool _debug;
  final bool _forceRelayCandidate;
  WebRTCStatsReporter? _statsManager;

  // Add negotiation timer fields
  Timer? _negotiationTimer;
  DateTime? _lastCandidateTime;
  static const int _negotiationTimeout = 500; // 500ms timeout for negotiation
  Function()? _onNegotiationComplete;

  final Map<String, Session> _sessions = {};
  MediaStream? _localStream;
  final List<MediaStream> _remoteStreams = <MediaStream>[];

  /// Callback for when the signaling state changes.
  Function(SignalingState state)? onSignalingStateChange;

  /// Callback for when the call state changes.
  Function(Session session, CallState state)? onCallStateChange;

  /// Callback for when the local media stream is available.
  Function(MediaStream stream)? onLocalStream;

  /// Callback for when a remote media stream is added.
  Function(Session session, MediaStream stream)? onAddRemoteStream;

  /// Callback for when a remote media stream is removed.
  Function(Session session, MediaStream stream)? onRemoveRemoteStream;

  /// Callback for when peer updates occur.
  Function(dynamic event)? onPeersUpdate;

  /// Callback for when a data channel message is received.
  Function(Session session, RTCDataChannel dc, RTCDataChannelMessage data)?
  onDataChannelMessage;

  /// Callback for when a data channel is available.
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
        'url': DefaultConfig.defaultStun,
        'username': DefaultConfig.username,
        'credential': DefaultConfig.password,
      },
      {
        'url': DefaultConfig.defaultTurn,
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

  /// Closes the peer connection and cleans up sessions.
  void close() async {
    await _cleanSessions();
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
  ///
  /// [enable] True to enable speakerphone, false to disable.
  void enableSpeakerPhone(bool enable) {
    if (_localStream != null) {
      _localStream!.getAudioTracks()[0].enableSpeakerphone(enable);
    } else {
      GlobalLogger().d(
        'Peer :: No local stream :: Unable to toggle speaker mode',
      );
    }
  }

  /// Initiates a call.
  ///
  /// [callerName] The name of the caller.
  /// [callerNumber] The number of the caller.
  /// [destinationNumber] The number to call.
  /// [clientState] The client state.
  /// [callId] The unique ID of the call.
  /// [telnyxSessionId] The Telnyx session ID.
  /// [customHeaders] Custom headers to include in the invite.
  void invite(
    String callerName,
    String callerNumber,
    String destinationNumber,
    String clientState,
    String callId,
    String telnyxSessionId,
    Map<String, String> customHeaders,
  ) async {
    final sessionId = _selfId;

    final Session session = await _createSession(
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
    String sessionId,
    Map<String, String> customHeaders,
  ) async {
    try {
      final RTCSessionDescription s = await session.peerConnection!.createOffer(
        _dcConstraints,
      );
      await session.peerConnection!.setLocalDescription(s);

      if (session.remoteCandidates.isNotEmpty) {
        for (var candidate in session.remoteCandidates) {
          if (candidate.candidate != null) {
            GlobalLogger().i('adding $candidate');
            await session.peerConnection?.addCandidate(candidate);
          }
        }
        session.remoteCandidates.clear();
      }

      await Future.delayed(const Duration(milliseconds: 500));

      String? sdpUsed = '';
      await session.peerConnection?.getLocalDescription().then(
        (value) => sdpUsed = value?.sdp.toString(),
      );

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
          sessid: sessionId,
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
      GlobalLogger().e('Peer :: $e');
    }
  }

  /// Sets the remote session description when an answer is received.
  ///
  /// [sdp] The SDP string of the remote description.
  void remoteSessionReceived(String sdp) async {
    await _sessions[_selfId]?.peerConnection?.setRemoteDescription(
      RTCSessionDescription(sdp, 'answer'),
    );
  }

  /// Accepts an incoming call.
  ///
  /// [callerName] The name of the caller.
  /// [callerNumber] The number of the caller.
  /// [destinationNumber] The destination number (usually the current user's number).
  /// [clientState] The client state.
  /// [callId] The unique ID of the call.
  /// [invite] The incoming invite parameters.
  /// [customHeaders] Custom headers to include in the answer.
  /// [isAttach] Whether this is an attach call.
  void accept(
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
    final Session session = await _createSession(
      null,
      peerId: Uuid().v4(),
      sessionId: sessionId,
      callId: callId,
      media: 'audio',
    );
    _sessions[sessionId] = session;

    await session.peerConnection?.setRemoteDescription(
      RTCSessionDescription(invite.sdp, 'offer'),
    );

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
      session.peerConnection?.onIceCandidate = (candidate) async {
        if (session.peerConnection != null) {
          GlobalLogger().i(
            'Peer :: onIceCandidate in _createAnswer received: ${candidate.candidate}',
          );
          if (candidate.candidate != null) {
            final candidateString = candidate.candidate.toString();
            final isValidCandidate =
                candidateString.contains('stun.telnyx.com') ||
                candidateString.contains('turn.telnyx.com');

            if (isValidCandidate) {
              GlobalLogger().i('Peer :: Valid ICE candidate: $candidateString');
              // Only add valid candidates and reset timer
              await session.peerConnection?.addCandidate(candidate);
              _lastCandidateTime = DateTime.now();
            } else {
              GlobalLogger().i(
                'Peer :: Ignoring non-STUN/TURN candidate: $candidateString',
              );
            }
          }
        } else {
          // Still collect candidates if peerConnection is not ready yet
          session.remoteCandidates.add(candidate);
        }
      };

      final RTCSessionDescription s = await session.peerConnection!
          .createAnswer(_dcConstraints);
      await session.peerConnection!.setLocalDescription(s);

      // Start ICE candidate gathering and wait for negotiation to complete
      _lastCandidateTime = DateTime.now();
      _setOnNegotiationComplete(() async {
        String? sdpUsed = '';
        await session.peerConnection?.getLocalDescription().then(
          (value) => sdpUsed = value?.sdp.toString(),
        );

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
          sessid: session.sid,
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
      GlobalLogger().e('Peer :: $e');
    }
  }

  /// Closes the current session.
  void closeSession() {
    final sess = _sessions[_selfId];
    if (sess != null) {
      GlobalLogger().i('Session end success');
      _closeSession(sess);
    } else {
      GlobalLogger().d('Session end failed');
    }
  }

  /// Creates a local media stream.
  ///
  /// [media] The type of media to create (e.g., 'audio').
  /// Returns a [Future] that completes with the [MediaStream].
  Future<MediaStream> createStream(String media) async {
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

  Future<Session> _createSession(
    Session? session, {
    required String peerId,
    required String sessionId,
    required String callId,
    required String media,
  }) async {
    final newSession = session ?? Session(sid: sessionId, pid: peerId);
    if (media != 'data') _localStream = await createStream(media);

    peerConnection = await createPeerConnection({
      ..._buildIceConfiguration(),
      ...{'sdpSemantics': sdpSemantics},
    }, _dcConstraints);

    await startStats(callId, peerId, onCallQualityChange: onCallQualityChange);

    if (media != 'data') {
      switch (sdpSemantics) {
        case 'plan-b':
          peerConnection?.onAddStream = (MediaStream stream) {
            onAddRemoteStream?.call(newSession, stream);
            _remoteStreams.add(stream);
          };
          await peerConnection?.addStream(_localStream!);
          break;
        case 'unified-plan':
          // Unified-Plan
          peerConnection?.onTrack = (event) {
            if (event.track.kind == 'video') {
              onAddRemoteStream?.call(newSession, event.streams[0]);
            } else if (event.track.kind == 'audio') {
              onAddRemoteStream?.call(newSession, event.streams[0]);
            }
          };
          _localStream!.getTracks().forEach((track) {
            peerConnection?.addTrack(track, _localStream!);
          });
          break;
      }
    }

    peerConnection?.onIceCandidate = (candidate) async {
      GlobalLogger().i(
        'Peer :: onIceCandidate in _createSession received: ${candidate.candidate}',
      );
      if (candidate.candidate != null) {
        final candidateString = candidate.candidate.toString();
        final isValidCandidate =
            candidateString.contains('stun.telnyx.com') ||
            candidateString.contains('turn.telnyx.com');

        if (isValidCandidate) {
          GlobalLogger().i('Peer :: Valid ICE candidate: $candidateString');
          // Add valid candidates
          await peerConnection?.addCandidate(candidate);
        } else {
          GlobalLogger().i(
            'Peer :: Ignoring non-STUN/TURN candidate: $candidateString',
          );
        }
      } else {
        GlobalLogger().i('Peer :: onIceCandidate: complete!');
      }
    };

    peerConnection?.onIceConnectionState = (state) {
      GlobalLogger().i('Peer :: ICE Connection State change :: $state');
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          final Call? currentCall = _txClient.calls[callId];
          currentCall?.callHandler.changeState(CallState.active);
          onCallStateChange?.call(newSession, CallState.active);

          // Automatically disable speaker phone to fix Android default behavior
          // This ensures calls start with earpiece audio routing by default on Android
          if (Platform.isAndroid) {
            Future.delayed(const Duration(milliseconds: 100), () {
              currentCall?.enableSpeakerPhone(false);
              GlobalLogger().i(
                'Peer :: Automatically disabled speaker phone for Android call',
              );
            });
          }

          // Cancel any reconnection timer for this call
          _txClient.onCallStateChangedToActive(callId);
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          peerConnection?.restartIce();
          return;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _statsManager?.stopStatsReporting();
          return;
        default:
          return;
      }
    };

    peerConnection?.onRemoveStream = (stream) {
      onRemoveRemoteStream?.call(newSession, stream);
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };

    peerConnection?.onDataChannel = (channel) {
      _addDataChannel(newSession, channel);
    };

    newSession.peerConnection = peerConnection;
    return newSession;
  }

  void _addDataChannel(Session session, RTCDataChannel channel) {
    channel
      ..onDataChannelState = (e) {}
      ..onMessage = (RTCDataChannelMessage data) {
        onDataChannelMessage?.call(session, channel, data);
      };
    session.dc = channel;
    onDataChannel?.call(session, channel);
  }

  /// Starts reporting WebRTC statistics.
  ///
  /// [callId] The ID of the call.
  /// [peerId] The ID of the peer.
  /// [onCallQualityChange] Callback for call quality updates.
  /// Returns a [Future] that completes with true if stats reporting started successfully, false otherwise.
  Future<bool> startStats(
    String callId,
    String peerId, {
    CallQualityCallback? onCallQualityChange,
  }) async {
    if (_debug == false) {
      GlobalLogger().d(
        'Peer :: Stats manager will not start. Debug mode not enabled on config',
      );
      return false;
    }

    if (peerConnection == null) {
      GlobalLogger().d('Peer connection null');
      return false;
    }

    _statsManager = WebRTCStatsReporter(
      _socket,
      peerConnection!,
      callId,
      peerId,
      _txClient.isDebug(),
      onCallQualityChange: onCallQualityChange,
    );
    await _statsManager?.startStatsReporting();

    return true;
  }

  /// Stops reporting WebRTC statistics for a specific call.
  ///
  /// [callId] The ID of the call to stop stats for.
  void stopStats(String callId) {
    if (_debug == false) {
      return;
    }
    _statsManager?.stopStatsReporting();
    GlobalLogger().i('Peer :: Stats Manager stopped for $callId');
  }

  void _send(event) {
    _socket.send(event);
  }

  Future<void> _cleanSessions() async {
    if (_localStream != null) {
      _localStream!.getTracks().forEach((element) async {
        await element.stop();
      });
      await _localStream!.dispose();
      _localStream = null;
    }
    _sessions
      ..forEach((key, sess) async {
        await sess.peerConnection?.close();
        await sess.dc?.close();
      })
      ..clear();
  }

  /*void _closeSessionByPeerId(String peerId) {
    Session? session;
    _sessions.removeWhere((String key, Session sess) {
      var ids = key.split('-');
      session = sess;
      return peerId == ids[0] || peerId == ids[1];
    });
    if (session != null) {
      _closeSession(session!);
      onCallStateChange?.call(session!, CallState.CallStateBye);
    }
  }*/

  Future<void> _closeSession(Session session) async {
    _localStream?.getTracks().forEach((element) async {
      await element.stop();
    });
    await _localStream?.dispose();
    _localStream = null;
    await session.peerConnection?.close();
    await session.peerConnection?.dispose();
    await session.dc?.close();
    stopStats(session.sid);
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
    if (peerConnection != null) {
      _cleanSessions();
    }
  }
}
