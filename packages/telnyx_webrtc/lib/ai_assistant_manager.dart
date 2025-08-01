import 'dart:convert';
import 'package:telnyx_webrtc/model/verto/send/anonymous_login_message.dart';
import 'package:telnyx_webrtc/model/verto/receive/ai_conversation_message.dart';
import 'package:telnyx_webrtc/model/transcript_item.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/jsonrpc.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:uuid/uuid.dart';

/// Callback for AI conversation events
typedef OnAiConversationReceived = void Function(AiConversationParams params);

/// Callback for transcript updates
typedef OnTranscriptUpdate = void Function(List<TranscriptItem> transcript);

/// Callback for widget settings updates
typedef OnWidgetSettingsUpdate = void Function(WidgetSettings settings);

/// Callback for sending messages through the socket
typedef OnSendMessage = void Function(String message);

/// Callback for connection management
typedef OnConnectWithCallback = void Function(void Function()? callback, void Function() onConnected);

/// Delegate protocol for AI Assistant Manager callbacks
abstract class AIAssistantManagerDelegate {
  /// Called when an AI conversation message is received
  void onAiConversationReceived(AiConversationParams params);
  
  /// Called when transcript is updated
  void onTranscriptUpdated(List<TranscriptItem> transcript);
  
  /// Called when widget settings are updated
  void onWidgetSettingsUpdate(WidgetSettings settings);
  
  /// Called to send a message through the socket
  void sendMessage(String message);
  
  /// Called to check if the socket is connected
  bool isConnected();
  
  /// Called to connect with a callback
  void connectWithCallback(void Function()? callback, void Function() onConnected);
  
  /// Called to get the current session ID
  String? getSessionId();
}

/// Manager class for AI Assistant functionality
/// 
/// This class handles all AI assistant related operations including:
/// - Anonymous login for AI assistants
/// - AI conversation message processing
/// - Transcript management
/// - Widget settings management
/// - Connection state tracking for AI assistants
class AIAssistantManager {
  /// Delegate for handling callbacks
  AIAssistantManagerDelegate? delegate;
  
  /// Current AI assistant connection state
  bool _isConnectedToAssistant = false;
  
  /// Current target information
  String? _currentTargetId;
  String? _currentTargetType;
  String? _currentTargetVersionId;
  
  /// Current widget settings from AI conversation
  WidgetSettings? _currentWidgetSettings;
  
  /// Transcript management
  final List<TranscriptItem> _transcript = [];
  final Map<String, StringBuffer> _assistantResponseBuffers = {};
  
  /// Constructor
  AIAssistantManager({this.delegate});
  
  /// Get current connection state to AI assistant
  bool get isConnectedToAssistant => _isConnectedToAssistant;
  
  /// Get current target ID
  String? get currentTargetId => _currentTargetId;
  
  /// Get current target type
  String? get currentTargetType => _currentTargetType;
  
  /// Get current target version ID
  String? get currentTargetVersionId => _currentTargetVersionId;
  
  /// Get current widget settings
  WidgetSettings? get currentWidgetSettings => _currentWidgetSettings;
  
  /// Get current transcript
  List<TranscriptItem> get transcript => List.unmodifiable(_transcript);
  
  /// Performs anonymous login to an AI assistant
  ///
  /// This method establishes a connection to an AI assistant without requiring
  /// traditional user credentials. It's specifically designed for AI assistant
  /// interactions.
  ///
  /// Parameters:
  /// - [targetId]: The unique identifier of the AI assistant to connect to
  /// - [targetType]: The type of target (defaults to 'ai_assistant')
  /// - [targetVersionId]: Optional version ID of the target
  /// - [userVariables]: Optional user variables to include
  /// - [reconnection]: Whether this is a reconnection attempt (defaults to false)
  /// - [logLevel]: Log level for this operation (defaults to LogLevel.none)
  Future<void> anonymousLogin({
    required String targetId,
    String targetType = 'ai_assistant',
    String? targetVersionId,
    Map<String, dynamic>? userVariables,
    bool reconnection = false,
    LogLevel logLevel = LogLevel.none,
  }) async {
    if (delegate == null) {
      GlobalLogger().e('AIAssistantManager: No delegate set');
      return;
    }
    
    final uuid = const Uuid().v4();
    
    // Store current target information
    _currentTargetId = targetId;
    _currentTargetType = targetType;
    _currentTargetVersionId = targetVersionId;
    
    final versionData = await VersionUtils.getSDKVersion();
    final userAgentData = await VersionUtils.getUserAgent();

    final userAgent = UserAgent(
      sdkVersion: versionData,
      data: userAgentData,
    );

    final anonymousLoginParams = AnonymousLoginParams(
      targetType: targetType,
      targetId: targetId,
      targetVersionId: targetVersionId,
      userVariables: userVariables,
      reconnection: reconnection,
      userAgent: userAgent,
      sessionId: delegate!.getSessionId(),
    );

    final anonymousLoginMessage = AnonymousLoginMessage(
      id: uuid,
      method: SocketMethod.anonymousLogin,
      params: anonymousLoginParams,
      jsonrpc: JsonRPCConstant.jsonrpc,
    );

    final String jsonAnonymousLoginMessage = jsonEncode(anonymousLoginMessage);
    GlobalLogger().i('AIAssistantManager: Anonymous Login Message $jsonAnonymousLoginMessage');

    if (delegate!.isConnected()) {
      delegate!.sendMessage(jsonAnonymousLoginMessage);
      _isConnectedToAssistant = true;
    } else {
      delegate!.connectWithCallback(null, () {
        delegate!.sendMessage(jsonAnonymousLoginMessage);
        _isConnectedToAssistant = true;
      });
    }
  }
  
  /// Disconnects from the current AI assistant
  void disconnect() {
    _isConnectedToAssistant = false;
    _currentTargetId = null;
    _currentTargetType = null;
    _currentTargetVersionId = null;
    _currentWidgetSettings = null;
    _transcript.clear();
    _assistantResponseBuffers.clear();
    
    GlobalLogger().i('AIAssistantManager: Disconnected from AI assistant');
  }
  
  /// Processes AI conversation messages
  /// 
  /// This method should be called by the TelnyxClient when an AI conversation
  /// message is received from the WebSocket.
  void processAiConversationMessage(AiConversationParams params) {
    GlobalLogger().i('AIAssistantManager: Processing AI conversation message: ${params.type}');
    
    // Store widget settings if available
    if (params.widgetSettings != null) {
      _currentWidgetSettings = params.widgetSettings;
      GlobalLogger().i('AIAssistantManager: Widget settings updated');
      delegate?.onWidgetSettingsUpdate(params.widgetSettings!);
    }
    
    // Process message for transcript extraction
    _processAiConversationForTranscript(params);
    
    // Notify delegate
    delegate?.onAiConversationReceived(params);
  }
  
  /// Process AI conversation messages for transcript extraction
  void _processAiConversationForTranscript(AiConversationParams params) {
    if (params.type == null) return;

    switch (params.type) {
      case 'conversation.item.created':
        _handleConversationItemCreated(params);
        break;
      case 'response.text.delta':
        _handleResponseTextDelta(params);
        break;
      default:
        // Other AI conversation message types are ignored for transcript
        break;
    }
  }
  
  /// Handle user speech transcript from conversation.item.created messages
  void _handleConversationItemCreated(AiConversationParams params) {
    if (params.item?.role != 'user' || params.item?.status != 'completed') {
      return; // Only handle completed user messages
    }

    final content = params.item?.content;
    if (content == null || content.isEmpty) return;

    // Extract transcript from the first content item
    final transcript = content.first.transcript;
    if (transcript != null && transcript.isNotEmpty) {
      final transcriptItem = TranscriptItem(
        role: 'user',
        content: transcript,
        timestamp: DateTime.now(),
      );
      
      _transcript.add(transcriptItem);
      GlobalLogger().i('AIAssistantManager: Added user transcript: $transcript');
      
      // Notify delegate of transcript update
      delegate?.onTranscriptUpdated(List.unmodifiable(_transcript));
    }
  }
  
  /// Handle assistant response deltas from response.text.delta messages
  void _handleResponseTextDelta(AiConversationParams params) {
    final responseId = params.responseId;
    final delta = params.delta;
    
    if (responseId == null || delta == null) return;
    
    // Initialize buffer for this response if it doesn't exist
    if (!_assistantResponseBuffers.containsKey(responseId)) {
      _assistantResponseBuffers[responseId] = StringBuffer();
    }
    
    // Append delta to the buffer
    _assistantResponseBuffers[responseId]!.write(delta);
    
    // Create or update transcript item for this response
    final currentContent = _assistantResponseBuffers[responseId]!.toString();
    
    // Find existing transcript item for this response or create new one
    final existingIndex = _transcript.indexWhere(
      (item) => item.role == 'assistant' && item.responseId == responseId,
    );
    
    final transcriptItem = TranscriptItem(
      role: 'assistant',
      content: currentContent,
      timestamp: DateTime.now(),
      responseId: responseId,
    );
    
    if (existingIndex >= 0) {
      // Update existing item
      _transcript[existingIndex] = transcriptItem;
    } else {
      // Add new item
      _transcript.add(transcriptItem);
    }
    
    GlobalLogger().i('AIAssistantManager: Updated assistant response: $currentContent');
    
    // Notify delegate of transcript update
    delegate?.onTranscriptUpdated(List.unmodifiable(_transcript));
  }
  
  /// Clears the current transcript
  void clearTranscript() {
    _transcript.clear();
    _assistantResponseBuffers.clear();
    GlobalLogger().i('AIAssistantManager: Transcript cleared');
    
    // Notify delegate of transcript update
    delegate?.onTranscriptUpdated(List.unmodifiable(_transcript));
  }
  
  /// Gets the current connection status as a string
  String getConnectionStatus() {
    if (_isConnectedToAssistant && _currentTargetId != null) {
      return 'Connected to $_currentTargetType: $_currentTargetId';
    }
    return 'Not connected to AI assistant';
  }
}