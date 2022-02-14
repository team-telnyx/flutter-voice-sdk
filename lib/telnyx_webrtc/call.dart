import 'package:telnyx_flutter_webrtc/telnyx_webrtc/peer/peer.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/tx_socket.dart';
import 'package:uuid/uuid.dart';

import 'model/verto/receive/incoming_invitation_body.dart';

class Call {
  Call(this._txSocket, this._telnyxClient, this._sessionId);

  final TxSocket _txSocket;
  final TelnyxClient _telnyxClient;
  final String? _sessionId;
  late String callId;
  late Peer peerConnection;

  void newInvite(String callerName, String callerNumber,
      String destinationNumber, String clientState) {
    var inviteCallId = const Uuid().toString();
    callId = inviteCallId;

    peerConnection = Peer(_txSocket);
    peerConnection.invite("0", "audio", callerName, callerNumber,
        destinationNumber, clientState, callId);
  }

  void acceptCall(IncomingInvitation invite, String callerName, String callerNumber,
      String clientState) {
    var callId = invite.params?.callID;
    var destinationNum = invite.params?.calleeIdNumber;

    peerConnection = Peer(_txSocket);
    peerConnection.accept("0", "audio", callerName, callerNumber,
        destinationNum!, clientState, callId!);
  }
}
