/// Model class for ConversationMessage
/// This represents the structure of a conversation message for a Telnyx AI Agent
class ConversationMessage {
  String? id;
  String? jsonrpc;
  String? method;
  ConversationMessageParams? params;

  ConversationMessage({this.id, this.jsonrpc, this.method, this.params});

  ConversationMessage.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    jsonrpc = json['jsonrpc'];
    method = json['method'];
    params = json['params'] != null
        ? ConversationMessageParams.fromJson(json['params'])
        : null;
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

/// Model class for ConversationMessageParams
/// This represents the parameters of a conversation message
class ConversationMessageParams {
  String? type;
  String? previousItemId;
  ConversationItemData? item;

  ConversationMessageParams({this.type, this.previousItemId, this.item});

  ConversationMessageParams.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    previousItemId = json['previous_item_id'];
    item = json['item'] != null
        ? ConversationItemData.fromJson(json['item'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['type'] = type;
    data['previous_item_id'] = previousItemId;
    if (item != null) {
      data['item'] = item!.toJson();
    }
    return data;
  }
}

/// Model class for ConversationItemData
/// This represents an item in the conversation, such as a message from the user or the AI agent
class ConversationItemData {
  String? id;
  String? type;
  String? role;
  List<ConversationContentData>? content;

  ConversationItemData({this.id, this.type, this.role, this.content});

  ConversationItemData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    type = json['type'];
    role = json['role'];
    if (json['content'] != null) {
      content = <ConversationContentData>[];
      json['content'].forEach((v) {
        content!.add(ConversationContentData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['type'] = type;
    data['role'] = role;
    if (content != null) {
      data['content'] = content!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

/// Model class for ConversationContentData
/// This represents the content of a conversation item, such as text
class ConversationContentData {
  String? type;
  String? text;

  ConversationContentData({this.type, this.text});

  ConversationContentData.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    text = json['text'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['type'] = type;
    data['text'] = text;
    return data;
  }
}
