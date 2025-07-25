/// Model for AI conversation messages received from the WebSocket
class AiConversationMessage {
  String? id;
  String? jsonrpc;
  String? method;
  AiConversationParams? params;

  AiConversationMessage({this.id, this.jsonrpc, this.method, this.params});

  AiConversationMessage.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    jsonrpc = json['jsonrpc'];
    method = json['method'];
    params = json['params'] != null
        ? AiConversationParams.fromJson(json['params'])
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

/// Parameters for AI conversation messages
class AiConversationParams {
  String? type;
  WidgetSettings? widgetSettings;

  AiConversationParams({this.type, this.widgetSettings});

  AiConversationParams.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    widgetSettings = json['widget_settings'] != null
        ? WidgetSettings.fromJson(json['widget_settings'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['type'] = type;
    if (widgetSettings != null) {
      data['widget_settings'] = widgetSettings!.toJson();
    }
    return data;
  }
}

/// Widget settings configuration
class WidgetSettings {
  String? agentThinkingText;
  AudioVisualizerConfig? audioVisualizerConfig;
  String? defaultState;
  String? giveFeedbackUrl;
  String? logoIconUrl;
  String? position;
  String? reportIssueUrl;
  String? speakToInterruptText;
  String? startCallText;
  String? theme;
  String? viewHistoryUrl;

  WidgetSettings({
    this.agentThinkingText,
    this.audioVisualizerConfig,
    this.defaultState,
    this.giveFeedbackUrl,
    this.logoIconUrl,
    this.position,
    this.reportIssueUrl,
    this.speakToInterruptText,
    this.startCallText,
    this.theme,
    this.viewHistoryUrl,
  });

  WidgetSettings.fromJson(Map<String, dynamic> json) {
    agentThinkingText = json['agent_thinking_text'];
    audioVisualizerConfig = json['audio_visualizer_config'] != null
        ? AudioVisualizerConfig.fromJson(json['audio_visualizer_config'])
        : null;
    defaultState = json['default_state'];
    giveFeedbackUrl = json['give_feedback_url'];
    logoIconUrl = json['logo_icon_url'];
    position = json['position'];
    reportIssueUrl = json['report_issue_url'];
    speakToInterruptText = json['speak_to_interrupt_text'];
    startCallText = json['start_call_text'];
    theme = json['theme'];
    viewHistoryUrl = json['view_history_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['agent_thinking_text'] = agentThinkingText;
    if (audioVisualizerConfig != null) {
      data['audio_visualizer_config'] = audioVisualizerConfig!.toJson();
    }
    data['default_state'] = defaultState;
    data['give_feedback_url'] = giveFeedbackUrl;
    data['logo_icon_url'] = logoIconUrl;
    data['position'] = position;
    data['report_issue_url'] = reportIssueUrl;
    data['speak_to_interrupt_text'] = speakToInterruptText;
    data['start_call_text'] = startCallText;
    data['theme'] = theme;
    data['view_history_url'] = viewHistoryUrl;
    return data;
  }
}

/// Audio visualizer configuration
class AudioVisualizerConfig {
  String? color;
  String? preset;

  AudioVisualizerConfig({this.color, this.preset});

  AudioVisualizerConfig.fromJson(Map<String, dynamic> json) {
    color = json['color'];
    preset = json['preset'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['color'] = color;
    data['preset'] = preset;
    return data;
  }
}