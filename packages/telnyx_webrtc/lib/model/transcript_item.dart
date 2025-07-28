/// Represents a single item in a conversation transcript
class TranscriptItem {
  /// Unique identifier for the transcript item
  final String id;
  
  /// Role of the speaker - 'user' for user speech, 'assistant' for AI response
  final String role;
  
  /// The text content of the transcript item
  final String content;
  
  /// Timestamp when the transcript item was created
  final DateTime timestamp;

  TranscriptItem({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  TranscriptItem.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        role = json['role'] as String,
        content = json['content'] as String,
        timestamp = DateTime.parse(json['timestamp'] as String);

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() => 'TranscriptItem(id: $id, role: $role, content: $content)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TranscriptItem &&
        other.id == id &&
        other.role == role &&
        other.content == content &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(id, role, content, timestamp);
}