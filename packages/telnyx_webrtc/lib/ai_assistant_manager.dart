import 'dart:async';
import 'dart:convert';
import 'package:telnyx_webrtc/model/jsonrpc.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/transcript_item.dart';
import 'package:telnyx_webrtc/model/verto/receive/ai_conversation_message.dart';
import 'package:telnyx_webrtc/model/verto/send/anonymous_login_message.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';
import 'package:uuid/uuid.dart';

/// Callback for when transcript updates occur
typedef OnAITranscriptUpdate = void Function(List<TranscriptItem> transcript);

/// Delegate protocol for AIAssistantManager to communicate with TelnyxClient
abstract class AIAssistantManagerDelegate {
  /// Send a message through the socket
  void sendMessage(String message);
  
  /// Check if the socket is connected
  bool isAssistantConnected();
  
  /// Connect with a callback to execute after connection
  void connectWithCallback(void Function()? callback, void Function() onConnected);
  
  /// Get the current session ID
  String? get sessionId;
  
  /// Set the log level
  void setAssistantLogLevel(LogLevel logLevel);
}

/// Manager class for AI Assistant functionality
/// Handles anonymous login, conversation processing, and transcript management
class AIAssistantManager {
  final AIAssistantManagerDelegate _delegate;
  
  /// Callback for when transcript updates occur
  OnAITranscriptUpdate? onTranscriptUpdate;
  
  /// Current conversation transcript
  final List<TranscriptItem> _transcript = [];
  
  /// Buffers for accumulating assistant response text deltas
  final Map<String, StringBuffer> _assistantResponseBuffers = <String, StringBuffer>{};
  
  /// Current AI assistant connection state
  String? _currentTargetId;
  String? _currentTargetType;
  String? _currentTargetVersionId;
  
  AIAssistantManager(this._delegate);
  
  /// Gets the current conversation transcript
  List<TranscriptItem> get transcript => List.unmodifiable(_transcript);
  
  /// Gets the current target ID
  String? get currentTargetId => _currentTargetId;
  
  /// Gets the current target type
  String? get currentTargetType => _currentTargetType;
  
  /// Gets the current target version ID
  String? get currentTargetVersionId => _currentTargetVersionId;
  
  /// Clears the conversation transcript
  void clearTranscript() {
    _transcript.clear();
    _assistantResponseBuffers.clear();
    onTranscriptUpdate?.call(_transcript);
  }
  
  /// Performs anonymous login to connect to an AI assistant
  ///
  /// This method establishes a connection to an AI assistant without requiring
  /// traditional user authentication. It's designed for AI assistant interactions
  /// where the user doesn't need to provide credentials.
  ///
  /// Parameters:
  /// - [targetId]: The unique identifier of the AI assistant to connect to
  /// - [targetType]: The type of target (defaults to 'ai_assistant')
  /// - [targetVersionId]: Optional version ID of the target
  /// - [userVariables]: Optional user variables to include
  /// - [reconnection]: Whether this is a reconnection attempt (defaults to false)
  /// - [logLevel]: The logging level for this operation
  Future<void> anonymousLogin({
    required String targetId,
    String targetType = 'ai_assistant',
    String? targetVersionId,
    Map<String, dynamic>? userVariables,
    bool reconnection = false,
    LogLevel logLevel = LogLevel.none,
  }) async {
    final uuid = const Uuid().v4();

    _delegate.setAssistantLogLevel(logLevel);
    
    // Store current connection state
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
      sessionId: _delegate.sessionId,
    );

    final anonymousLoginMessage = AnonymousLoginMessage(
      id: uuid,
      method: SocketMethod.anonymousLogin,
      params: anonymousLoginParams,
      jsonrpc: JsonRPCConstant.jsonrpc,
    );

    final String jsonAnonymousLoginMessage = jsonEncode(anonymousLoginMessage);
    GlobalLogger().i('Anonymous Login Message $jsonAnonymousLoginMessage');

    if (_delegate.isAssistantConnected()) {
      _delegate.sendMessage(jsonAnonymousLoginMessage);
    } else {
      _delegate.connectWithCallback(null, () {
        _delegate.sendMessage(jsonAnonymousLoginMessage);
      });
    }
  }
  
  /// Disconnects from the current AI assistant
  void disconnect() {
    _currentTargetId = null;
    _currentTargetType = null;
    _currentTargetVersionId = null;
    clearTranscript();
  }
  
  /// Process AI conversation messages for transcript extraction
  void processAiConversationMessage(AiConversationParams? params) {
    if (params?.type == null) return;

    switch (params!.type) {
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

    final content = params.item?.content
        ?.where((c) => c.transcript != null)
        .map((c) => c.transcript!)
        .join(' ') ?? '';

    if (content.isNotEmpty && params.item?.id != null) {
      final transcriptItem = TranscriptItem(
        id: params.item!.id!,
        role: 'user',
        content: content,
        timestamp: DateTime.now(),
      );

      _transcript.add(transcriptItem);
      onTranscriptUpdate?.call(List.unmodifiable(_transcript));
    }
  }

  /// Handle AI response text deltas from response.text.delta messages
  void _handleResponseTextDelta(AiConversationParams params) {
    if (params.delta == null || params.itemId == null) return;

    final itemId = params.itemId!;
    final delta = params.delta!;

    // Initialize buffer for this response if not exists
    _assistantResponseBuffers.putIfAbsent(itemId, () => StringBuffer());
    _assistantResponseBuffers[itemId]!.write(delta);

    // Create or update transcript item for this response
    final existingIndex = _transcript.indexWhere((item) => item.id == itemId);
    final currentContent = _assistantResponseBuffers[itemId]!.toString();

    if (existingIndex >= 0) {
      // Update existing transcript item with accumulated content
      _transcript[existingIndex] = TranscriptItem(
        id: itemId,
        role: 'assistant',
        content: currentContent,
        timestamp: _transcript[existingIndex].timestamp,
      );
    } else {
      // Create new transcript item
      final transcriptItem = TranscriptItem(
        id: itemId,
        role: 'assistant',
        content: currentContent,
        timestamp: DateTime.now(),
      );
      _transcript.add(transcriptItem);
    }

    onTranscriptUpdate?.call(List.unmodifiable(_transcript));
  }
}