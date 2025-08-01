import 'package:uuid/uuid.dart';

/// Represents a single item in a conversation transcript with the AI assistant or user.
class TranscriptItem {
  /// Unique identifier for the transcript item
  final String id;
  
  /// Role of the speaker - 'user' for user speech, 'assistant' for AI response
  final String role;
  
  /// The text content of the transcript item
  final String content;
  
  /// Timestamp when the transcript item was created
  final DateTime timestamp;

  /// Optional flag indicating if the item is a partial response
  final bool? isPartial;
  
  /// Optional response ID for assistant responses (used for tracking deltas)
  final String? responseId;

  TranscriptItem({
    String? id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isPartial,
    this.responseId,
  }) : id = id ?? const Uuid().v4();

  TranscriptItem.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        role = json['role'] as String,
        content = json['content'] as String,
        timestamp = DateTime.parse(json['timestamp'] as String),
        isPartial = json['isPartial'] as bool? ?? false,
        responseId = json['responseId'] as String?;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'isPartial': isPartial ?? false,
        'responseId': responseId,
      };

  @override
  String toString() => 'TranscriptItem(id: $id, role: $role, content: $content, timestamp: $timestamp, isPartial: $isPartial, responseId: $responseId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TranscriptItem &&
        other.id == id &&
        other.role == role &&
        other.content == content &&
        other.timestamp == timestamp &&
        other.isPartial == isPartial &&
        other.responseId == responseId;
  }

  @override
  int get hashCode => Object.hash(id, role, content, timestamp, isPartial, responseId);
}