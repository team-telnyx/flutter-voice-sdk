### IncomingInviteParams

The `IncomingInviteParams` class represents the parameters for an incoming invite in a WebRTC session. It includes various details about the call and the participants.

- **callID**: A unique identifier for the call.
- **variables**: An instance of the `Variables` class containing additional event-related information.
- **sdp**: The Session Description Protocol (SDP) data for the call.
- **callerIdName**: The name of the caller.
- **callerIdNumber**: The phone number of the caller.
- **calleeIdName**: The name of the callee.
- **calleeIdNumber**: The phone number of the callee.
- **telnyxSessionId**: The session ID provided by Telnyx.
- **telnyxLegId**: The leg ID provided by Telnyx.
- **displayDirection**: The direction of the call display (e.g., inbound or outbound).

### Variables

The `Variables` class contains various event-related details that are part of the incoming invite parameters.

- **eventName**: The name of the event.
- **coreUUID**: The UUID of the core.
- **freeSWITCHHostname**: The hostname of the FreeSWITCH server.
- **freeSWITCHSwitchname**: The switch name of the FreeSWITCH server.
- **freeSWITCHIPv4**: The IPv4 address of the FreeSWITCH server.
- **freeSWITCHIPv6**: The IPv6 address of the FreeSWITCH server.
- **eventDateLocal**: The local date and time of the event.
- **eventDateGMT**: The GMT date and time of the event.
- **eventDateTimestamp**: The timestamp of the event.
- **eventCallingFile**: The file from which the event was called.
- **eventCallingFunction**: The function from which the event was called.
- **eventCallingLineNumber**: The line number from which the event was called.
- **eventSequence**: The sequence number of the event.

```dart
class IncomingInviteParams {
  String? callID;
  Variables? variables;
  String? sdp;
  String? callerIdName;
  String? callerIdNumber;
  String? calleeIdName;
  String? calleeIdNumber;
  String? telnyxSessionId;
  String? telnyxLegId;
  String? displayDirection;

  IncomingInviteParams({
    this.callID,
    this.variables,
    this.sdp,
    this.callerIdName,
    this.callerIdNumber,
    this.calleeIdName,
    this.calleeIdNumber,
    this.telnyxSessionId,
    this.telnyxLegId,
    this.displayDirection,
  });

  IncomingInviteParams.fromJson(Map<String, dynamic> json) {
    callID = json['callID'];
    variables = json['variables'] != null
        ? Variables.fromJson(json['variables'])
        : null;
    sdp = json['sdp'];
    callerIdName = json['caller_id_name'];
    callerIdNumber = json['caller_id_number'];
    calleeIdName = json['callee_id_name'];
    calleeIdNumber = json['callee_id_number'];
    telnyxSessionId = json['telnyx_session_id'];
    telnyxLegId = json['telnyx_leg_id'];
    displayDirection = json['display_direction'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['callID'] = callID;
    if (variables != null) {
      data['variables'] = variables!.toJson();
    }
    data['sdp'] = sdp;
    data['caller_id_name'] = callerIdName;
    data['caller_id_number'] = callerIdNumber;
    data['callee_id_name'] = calleeIdName;
    data['callee_id_number'] = calleeIdNumber;
    data['telnyx_session_id'] = telnyxSessionId;
    data['telnyx_leg_id'] = telnyxLegId;
    data['display_direction'] = displayDirection;
    return data;
  }
}

class Variables {
  String? eventName;
  String? coreUUID;
  String? freeSWITCHHostname;
  String? freeSWITCHSwitchname;
  String? freeSWITCHIPv4;
  String? freeSWITCHIPv6;
  String? eventDateLocal;
  String? eventDateGMT;
  String? eventDateTimestamp;
  String? eventCallingFile;
  String? eventCallingFunction;
  String? eventCallingLineNumber;
  String? eventSequence;

  Variables({
    this.eventName,
    this.coreUUID,
    this.freeSWITCHHostname,
    this.freeSWITCHSwitchname,
    this.freeSWITCHIPv4,
    this.freeSWITCHIPv6,
    this.eventDateLocal,
    this.eventDateGMT,
    this.eventDateTimestamp,
    this.eventCallingFile,
    this.eventCallingFunction,
    this.eventCallingLineNumber,
    this.eventSequence,
  });

  Variables.fromJson(Map<String, dynamic> json) {
    eventName = json['Event-Name'];
    coreUUID = json['Core-UUID'];
    freeSWITCHHostname = json['FreeSWITCH-Hostname'];
    freeSWITCHSwitchname = json['FreeSWITCH-Switchname'];
    freeSWITCHIPv4 = json['FreeSWITCH-IPv4'];
    freeSWITCHIPv6 = json['FreeSWITCH-IPv6'];
    eventDateLocal = json['Event-Date-Local'];
    eventDateGMT = json['Event-Date-GMT'];
    eventDateTimestamp = json['Event-Date-Timestamp'];
    eventCallingFile = json['Event-Calling-File'];
    eventCallingFunction = json['Event-Calling-Function'];
    eventCallingLineNumber = json['Event-Calling-Line-Number'];
    eventSequence = json['Event-Sequence'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['Event-Name'] = eventName;
    data['Core-UUID'] = coreUUID;
    data['FreeSWITCH-Hostname'] = freeSWITCHHostname;
    data['FreeSWITCH-Switchname'] = freeSWITCHSwitchname;
    data['FreeSWITCH-IPv4'] = freeSWITCHIPv4;
    data['FreeSWITCH-IPv6'] = freeSWITCHIPv6;
    data['Event-Date-Local'] = eventDateLocal;
    data['Event-Date-GMT'] = eventDateGMT;
    data['Event-Date-Timestamp'] = eventDateTimestamp;
    data['Event-Calling-File'] = eventCallingFile;
    data['Event-Calling-Function'] = eventCallingFunction;
    data['Event-Calling-Line-Number'] = eventCallingLineNumber;
    data['Event-Sequence'] = eventSequence;
    return data;
  }
}
```