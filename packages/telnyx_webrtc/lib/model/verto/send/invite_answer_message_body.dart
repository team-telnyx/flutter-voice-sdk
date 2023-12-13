class InviteAnswerMessage {
  String? id;
  String? jsonrpc;
  String? method;
  InviteParams? params;

  InviteAnswerMessage({this.id, this.jsonrpc, this.method, this.params});

  InviteAnswerMessage.fromJson(Map<String, dynamic> json) {
    id = json['id'].toString();
    jsonrpc = json['jsonrpc'];
    method = json['method'];
    params =
    json['params'] != null ? InviteParams.fromJson(json['params']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['jsonrpc'] = jsonrpc;
    data['method'] = method;
    if (params != null) {
      data['params'] = params!.toJson();
    }
    return data;
  }
}

class InviteParams {
  DialogParams? dialogParams;
  String? sdp;
  String? sessid;
  String? userAgent;

  InviteParams({this.dialogParams, this.sdp, this.sessid, this.userAgent});

  InviteParams.fromJson(Map<String, dynamic> json) {
    dialogParams = json['dialogParams'] != null
        ? DialogParams.fromJson(json['dialogParams'])
        : null;
    sdp = json['sdp'];
    sessid = json['sessid'];
    userAgent = json['User-Agent'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (dialogParams != null) {
      data['dialogParams'] = dialogParams!.toJson();
    }
    data['sdp'] = sdp;
    data['sessid'] = sessid;
    data['User-Agent'] = userAgent;
    return data;
  }
}

class DialogParams {
  bool? attach;
  bool? audio;
  String? callID;
  String? callerIdName;
  String? callerIdNumber;
  String? clientState;
  String? destinationNumber;
  String? remoteCallerIdName;
  bool? screenShare;
  bool? useStereo;
  List<dynamic>? userVariables;
  bool? video;
  Map<String, String>? customHeaders = {};

  DialogParams(
      {this.attach,
        this.audio,
        this.callID,
        this.callerIdName,
        this.callerIdNumber,
        this.clientState,
        this.destinationNumber,
        this.remoteCallerIdName,
        this.screenShare,
        this.useStereo,
        this.userVariables,
        this.video,
        this.customHeaders});

  DialogParams.fromJson(Map<String, dynamic> json) {
    attach = json['attach'];
    audio = json['audio'];
    callID = json['callID'];
    callerIdName = json['caller_id_name'];
    callerIdNumber = json['caller_id_number'];
    clientState = json['clientState'];
    destinationNumber = json['destination_number'];
    remoteCallerIdName = json['remote_caller_id_name'];
    screenShare = json['screenShare'];
    useStereo = json['useStereo'];
    if (json['userVariables'] != null) {
      userVariables = <Null>[];
      json['userVariables'].forEach((v) {
        userVariables!.add((v));
      });
    }
    if (json['custom_headers'] != null) {
      customHeaders = <String, String>{};
      json['custom_headers'].forEach((v) {
        customHeaders![v['name']] = v['value'];
      });
    }
    video = json['video'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['attach'] = attach;
    data['audio'] = audio;
    data['callID'] = callID;
    data['caller_id_name'] = callerIdName;
    data['caller_id_number'] = callerIdNumber;
    data['clientState'] = clientState;
    data['destination_number'] = destinationNumber;
    data['remote_caller_id_name'] = remoteCallerIdName;
    data['screenShare'] = screenShare;
    data['useStereo'] = useStereo;
    if (userVariables != null) {
      data['userVariables'] = userVariables!.map((v) => v.toJson()).toList();
    }
    if (customHeaders != null) {
      var headers =  <CustomHeader>[];
      customHeaders!.forEach((key, value) {
        headers.add(CustomHeader(name: key, value: value));
      });
      data['custom_headers'] = headers.map((e) => e.toJson()).toList();
    }
    data['video'] = video;
    return data;
  }
}

class CustomHeader {
  String? name;
  String? value;

  CustomHeader({this.name, this.value});

  CustomHeader.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['value'] = value;
    return data;
  }
}
