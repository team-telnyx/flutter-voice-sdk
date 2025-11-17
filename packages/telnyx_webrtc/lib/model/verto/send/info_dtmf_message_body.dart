import 'package:telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';

class DtmfInfoMessage {
  String? id;
  String? jsonrpc;
  String? method;
  InfoParams? params;

  DtmfInfoMessage({this.id, this.jsonrpc, this.method, this.params});

  DtmfInfoMessage.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    jsonrpc = json['jsonrpc'];
    method = json['method'];
    params =
        json['params'] != null ? InfoParams.fromJson(json['params']) : null;
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

class InfoParams {
  DialogParams? dialogParams;
  String? dtmf;
  String? sessid;

  InfoParams({this.dialogParams, this.dtmf, this.sessid});

  InfoParams.fromJson(Map<String, dynamic> json) {
    dialogParams = json['dialogParams'] != null
        ? DialogParams.fromJson(json['dialogParams'])
        : null;
    dtmf = json['dtmf'];
    sessid = json['sessid'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (dialogParams != null) {
      data['dialogParams'] = dialogParams!.toJson();
    }
    data['dtmf'] = dtmf;
    data['sessid'] = sessid;
    return data;
  }
}
