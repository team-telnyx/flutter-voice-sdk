import 'dart:convert';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/config.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/send/invite_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/tx_socket.dart';
import 'package:uuid/uuid.dart';

enum SignalingState {
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

enum CallState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
}

class Session {
  Session({required this.sid, required this.pid});

  String pid;
  String sid;
  RTCPeerConnection? pc;
  RTCDataChannel? dc;
  List<RTCIceCandidate> remoteCandidates = [];
}

class Peer {
  Peer(this._socket);

  final JsonEncoder _encoder = const JsonEncoder();
  final JsonDecoder _decoder = const JsonDecoder();

  // String _selfId = randomNumeric(6);
  final String _selfId = "123456";

  //SimpleWebSocket? _socket;
  final TxSocket _socket;

  //final _host;
  final _port = 8086;
  var _turnCredential;
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
        'credential': DefaultConfig.password
      },
      {
        'url': DefaultConfig.defaultTurn,
        'username': DefaultConfig.username,
        'credential': DefaultConfig.password
      },
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };

  close() async {
    await _cleanSessions();
    _socket.close();
  }

  void muteMic() {
    if (_localStream != null) {
      bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
    }
  }

  void invite(
      String peerId,
      String media,
      bool useScreen,
      String callerName,
      String callerNumber,
      String destinationNumber,
      String clientState,
      String callId) async {
    var sessionId = _selfId + '-' + peerId;
    Session session = await _createSession(null,
        peerId: peerId,
        sessionId: sessionId,
        media: media,
        screenSharing: useScreen);
    _sessions[sessionId] = session;
    if (media == 'data') {
      _createDataChannel(session);
    }
    _createOffer(session, media, callerName, callerNumber, destinationNumber,
        clientState, callId);
    onCallStateChange?.call(session, CallState.CallStateNew);
  }

  void bye(String sessionId) {
    /* _send('bye', {
      'session_id': sessionId,
      'from': _selfId,
    });*/
    var sess = _sessions[sessionId];
    if (sess != null) {
      _closeSession(sess);
    }
  }

  void onMessage(message) async {
    Map<String, dynamic> mapData = message;
    var data = mapData['data'];

    switch (mapData['type']) {
      case 'peers':
        {
          List<dynamic> peers = data;
          if (onPeersUpdate != null) {
            Map<String, dynamic> event = Map<String, dynamic>();
            event['self'] = _selfId;
            event['peers'] = peers;
            onPeersUpdate?.call(event);
          }
        }
        break;
      case 'offer':
        {
          var peerId = data['from'];
          var description = data['description'];
          var media = data['media'];
          var sessionId = data['session_id'];
          var session = _sessions[sessionId];
          var newSession = await _createSession(session,
              peerId: peerId,
              sessionId: sessionId,
              media: media,
              screenSharing: false);
          _sessions[sessionId] = newSession;
          await newSession.pc?.setRemoteDescription(
              RTCSessionDescription(description['sdp'], description['type']));
          await _createAnswer(newSession, media);
          if (newSession.remoteCandidates.isNotEmpty) {
            newSession.remoteCandidates.forEach((candidate) async {
              await newSession.pc?.addCandidate(candidate);
            });
            newSession.remoteCandidates.clear();
          }
          onCallStateChange?.call(newSession, CallState.CallStateNew);
        }
        break;
      case 'answer':
        {
          var description = data['description'];
          var sessionId = data['session_id'];
          var session = _sessions[sessionId];
          session?.pc?.setRemoteDescription(
              RTCSessionDescription(description['sdp'], description['type']));
        }
        break;
      case 'candidate':
        {
          var peerId = data['from'];
          var candidateMap = data['candidate'];
          var sessionId = data['session_id'];
          var session = _sessions[sessionId];
          RTCIceCandidate candidate = RTCIceCandidate(candidateMap['candidate'],
              candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);

          if (session != null) {
            if (session.pc != null) {
              await session.pc?.addCandidate(candidate);
            } else {
              session.remoteCandidates.add(candidate);
            }
          } else {
            _sessions[sessionId] = Session(pid: peerId, sid: sessionId)
              ..remoteCandidates.add(candidate);
          }
        }
        break;
      case 'leave':
        {
          var peerId = data as String;
          _closeSessionByPeerId(peerId);
        }
        break;
      case 'bye':
        {
          var sessionId = data['session_id'];
          print('bye: ' + sessionId);
          var session = _sessions.remove(sessionId);
          if (session != null) {
            onCallStateChange?.call(session, CallState.CallStateBye);
            _closeSession(session);
          }
        }
        break;
      case 'keepalive':
        {
          print('keepalive response!');
        }
        break;
      default:
        break;
    }
  }

  Future<MediaStream> createStream(String media, bool userScreen) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': {
        "exact": {
          "OfferToReceiveAudio": true
        }
      },
    };

    MediaStream stream = userScreen
        ? await navigator.mediaDevices.getDisplayMedia(mediaConstraints)
        : await navigator.mediaDevices.getUserMedia(mediaConstraints);
    onLocalStream?.call(stream);
    return stream;
  }

  Future<Session> _createSession(Session? session,
      {required String peerId,
      required String sessionId,
      required String media,
      required bool screenSharing}) async {
    var newSession = session ?? Session(sid: sessionId, pid: peerId);
    if (media != 'data')
      _localStream = await createStream(media, screenSharing);
    print(_iceServers);
    RTCPeerConnection pc = await createPeerConnection({
      ..._iceServers,
      ...{'sdpSemantics': sdpSemantics}
    }, _config);
    if (media != 'data') {
      switch (sdpSemantics) {
        case 'plan-b':
          pc.onAddStream = (MediaStream stream) {
            onAddRemoteStream?.call(newSession, stream);
            _remoteStreams.add(stream);
          };
          await pc.addStream(_localStream!);
          break;
        case 'unified-plan':
          // Unified-Plan
          pc.onTrack = (event) {
            if (event.track.kind == 'video') {
              onAddRemoteStream?.call(newSession, event.streams[0]);
            }
          };
          _localStream!.getTracks().forEach((track) {
            pc.addTrack(track, _localStream!);
          });
          break;
      }

      // Unified-Plan: Simuclast
      /*
      await pc.addTransceiver(
        track: _localStream.getAudioTracks()[0],
        init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendOnly, streams: [_localStream]),
      );
      await pc.addTransceiver(
        track: _localStream.getVideoTracks()[0],
        init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendOnly,
            streams: [
              _localStream
            ],
            sendEncodings: [
              RTCRtpEncoding(rid: 'f', active: true),
              RTCRtpEncoding(
                rid: 'h',
                active: true,
                scaleResolutionDownBy: 2.0,
                maxBitrate: 150000,
              ),
              RTCRtpEncoding(
                rid: 'q',
                active: true,
                scaleResolutionDownBy: 4.0,
                maxBitrate: 100000,
              ),
            ]),
      );*/
      /*
        var sender = pc.getSenders().find(s => s.track.kind == "video");
        var parameters = sender.getParameters();
        if(!parameters)
          parameters = {};
        parameters.encodings = [
          { rid: "h", active: true, maxBitrate: 900000 },
          { rid: "m", active: true, maxBitrate: 300000, scaleResolutionDownBy: 2 },
          { rid: "l", active: true, maxBitrate: 100000, scaleResolutionDownBy: 4 }
        ];
        sender.setParameters(parameters);
      */
    }
    pc.onIceCandidate = (candidate) async {
      if (candidate == null) {
        print('onIceCandidate: complete!');
        return;
      }
      // This delay is needed to allow enough time to try an ICE candidate
      // before skipping to the next one. 1 second is just an heuristic value
      // and should be thoroughly tested in your own environment.
      /* await Future.delayed(
          const Duration(seconds: 1),
              () => _send('candidate', {
            'to': peerId,
            'from': _selfId,
            'candidate': {
              'sdpMLineIndex': candidate.sdpMlineIndex,
              'sdpMid': candidate.sdpMid,
              'candidate': candidate.candidate,
            },
            'session_id': sessionId,
          }));*/
    };

    pc.onIceConnectionState = (state) {};

    pc.onRemoveStream = (stream) {
      onRemoveRemoteStream?.call(newSession, stream);
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };

    pc.onDataChannel = (channel) {
      _addDataChannel(newSession, channel);
    };

    newSession.pc = pc;
    return newSession;
  }

  void _addDataChannel(Session session, RTCDataChannel channel) {
    channel.onDataChannelState = (e) {};
    channel.onMessage = (RTCDataChannelMessage data) {
      onDataChannelMessage?.call(session, channel, data);
    };
    session.dc = channel;
    onDataChannel?.call(session, channel);
  }

  Future<void> _createDataChannel(Session session,
      {label: 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()
      ..maxRetransmits = 30;
    RTCDataChannel channel =
        await session.pc!.createDataChannel(label, dataChannelDict);
    _addDataChannel(session, channel);
  }

  Future<void> _createOffer(
      Session session,
      String media,
      String callerName,
      String callerNumber,
      String destinationNumber,
      String clientState,
      String callId) async {
    try {
      RTCSessionDescription s =
          await session.pc!.createOffer(media == 'data' ? _dcConstraints : {});
      await session.pc!.setLocalDescription(s);

      var dialogParams = DialogParams(
          attach: false,
          audio: true,
          callID: callId,
          callerIdName: callerNumber,
          callerIdNumber: callerNumber,
          clientState: clientState,
          destinationNumber: destinationNumber,
          remoteCallerIdName: "",
          screenShare: false,
          useStereo: false,
          userVariables: [],
          video: false);
      var inviteParams = InviteParams(
          dialogParams: dialogParams,
          sdp: s.sdp,
          sessionId: session.sid,
          userAgent: "Flutter-1.0");
      var inviteMessage = InviteMessage(
          id: const Uuid().toString(),
          jsonrpc: "2.0",
          method: "telnyx_rtc.invite",
          params: inviteParams);

      String jsonInviteMessage = jsonEncode(inviteMessage);

      _send(jsonInviteMessage);
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _createAnswer(Session session, String media) async {
    try {
      RTCSessionDescription s =
          await session.pc!.createAnswer(media == 'data' ? _dcConstraints : {});
      await session.pc!.setLocalDescription(s);
      /*_send('answer', {
        'to': session.pid,
        'from': _selfId,
        'description': {'sdp': s.sdp, 'type': s.type},
        'session_id': session.sid,
      });*/
    } catch (e) {
      print(e.toString());
    }
  }

  _send(event) {
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
    _sessions.forEach((key, sess) async {
      await sess.pc?.close();
      await sess.dc?.close();
    });
    _sessions.clear();
  }

  void _closeSessionByPeerId(String peerId) {
    var session;
    _sessions.removeWhere((String key, Session sess) {
      var ids = key.split('-');
      session = sess;
      return peerId == ids[0] || peerId == ids[1];
    });
    if (session != null) {
      _closeSession(session);
      onCallStateChange?.call(session, CallState.CallStateBye);
    }
  }

  Future<void> _closeSession(Session session) async {
    _localStream?.getTracks().forEach((element) async {
      await element.stop();
    });
    await _localStream?.dispose();
    _localStream = null;

    await session.pc?.close();
    await session.dc?.close();
  }
}
