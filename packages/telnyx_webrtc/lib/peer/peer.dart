import 'dart:convert';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';
import 'package:telnyx_webrtc/peer/session.dart';
import 'package:telnyx_webrtc/peer/signaling_state.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/utils/stats/webrtc_stats_reporter.dart';
import 'package:telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_webrtc/tx_socket_web.dart';
import 'package:telnyx_webrtc/utils/string_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/jsonrpc.dart';

class Peer {
  RTCPeerConnection? peerConnection;

  final debugStatsDelay = const Duration(milliseconds: 20000);

  Peer(this._socket, this._debug, this._txClient);

  final _logger = Logger();

  final String _selfId = randomNumeric(6);

  final TxSocket _socket;
  final TelnyxClient _txClient;
  final bool _debug;
  WebRTCStatsReporter? _statsManager;

  final Map<String, Session> _sessions = {};
  MediaStream? _localStream;
  final List<MediaStream> _remoteStreams = <MediaStream>[];

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

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': false,
    },
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  void close() async {
    await _cleanSessions();
  }

  void muteUnmuteMic() {
    if (_localStream != null) {
      final bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
    } else {
      _logger.d('Peer :: No local stream :: Unable to Mute / Unmute');
    }
  }

  void enableSpeakerPhone(bool enable) {
    if (_localStream != null) {
      _localStream!.getAudioTracks()[0].enableSpeakerphone(enable);
    } else {
      _logger.d('Peer :: No local stream :: Unable to toggle speaker mode');
    }
  }

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
      peerId: '0',
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
      final RTCSessionDescription s =
          await session.peerConnection!.createOffer(_dcConstraints);
      await session.peerConnection!.setLocalDescription(s);

      if (session.remoteCandidates.isNotEmpty) {
        for (var candidate in session.remoteCandidates) {
          if (candidate.candidate != null) {
            _logger.i('adding $candidate');
            await session.peerConnection?.addCandidate(candidate);
          }
        }
        session.remoteCandidates.clear();
      }

      await Future.delayed(const Duration(milliseconds: 500));

      String? sdpUsed = '';
      await session.peerConnection
          ?.getLocalDescription()
          .then((value) => sdpUsed = value?.sdp.toString());

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
          sessid: sessionId,
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
      _logger.e('Peer :: $e');
    }
  }

  void remoteSessionReceived(String sdp) async {
    await _sessions[_selfId]
        ?.peerConnection
        ?.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }

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
      peerId: '0',
      sessionId: sessionId,
      callId: callId,
      media: 'audio',
    );
    _sessions[sessionId] = session;

    await session.peerConnection
        ?.setRemoteDescription(RTCSessionDescription(invite.sdp, 'offer'));

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
          _logger.i('Peer :: Add Ice Candidate!');
          if (candidate.candidate != null) {
            await session.peerConnection?.addCandidate(candidate);
          }
        } else {
          session.remoteCandidates.add(candidate);
        }
      };

      final RTCSessionDescription s =
          await session.peerConnection!.createAnswer(_dcConstraints);
      await session.peerConnection!.setLocalDescription(s);

      await Future.delayed(const Duration(milliseconds: 500));

      String? sdpUsed = '';
      await session.peerConnection
          ?.getLocalDescription()
          .then((value) => sdpUsed = value?.sdp.toString());

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
          sessid: session.sid,
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
      _logger.e('Peer :: $e');
    }
  }

  void closeSession() {
    final sess = _sessions[_selfId];
    if (sess != null) {
      _logger.d('Session end success');
      _closeSession(sess);
    } else {
      _logger.d('Session end failed');
    }
  }

  Future<MediaStream> createStream(String media) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false,
    };

    final MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
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

    peerConnection = await createPeerConnection(
      {
        ..._iceServers,
        ...{'sdpSemantics': sdpSemantics},
      },
      _dcConstraints,
    );

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
      final Call? currentCall = _txClient.calls[callId];

      if (!candidate.candidate.toString().contains('127.0.0.1') ||
          currentCall?.callState != CallState.active) {
        _logger.i('Peer :: Adding ICE candidate :: ${candidate.toString()}');
        await peerConnection?.addCandidate(candidate);
      } else {
        _logger.i('Peer :: Local candidate skipped!');
      }
      if (candidate.candidate == null) {
        _logger.i('Peer :: onIceCandidate: complete!');
        return;
      }
    };

    peerConnection?.onIceConnectionState = (state) {
      _logger.i('Peer :: ICE Connection State change :: $state');
      switch (state) {
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

  Future<bool> startStats(String callId) async {
    if (_debug == false) {
      _logger.d(
        'Peer :: Stats manager will not start. Debug mode not enabled on config',
      );
      return false;
    }
    // Delay to allow call to be established
    //ToDo(Oli) - Remove this delay, let's rely on a connection state change instead
    await Future.delayed(debugStatsDelay);

    if (peerConnection == null) {
      _logger.d('Peer connection null');
      return false;
    }

    _statsManager = WebRTCStatsReporter(_socket, peerConnection!, callId);
    await _statsManager?.startStatsReporting();
    _logger.d('Peer :: Stats Manager started for $callId');

    return true;
  }

  void stopStats(String callId) {
    if (_debug == false) {
      return;
    }
    _statsManager?.stopStatsReporting();
    _logger.d('Peer :: Stats Manager stopped for $callId');
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
}
