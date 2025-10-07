/// Represents a single item in a conversation transcript with the AI assistant or user.
class TranscriptItem {
  /// Unique identifier for the transcript item
  final String id;

  /// Role of the speaker - 'user' for user speech, 'assistant' for AI response
  final String role;

  /// The text content of the transcript item
  final String content;

  /// Optional list of image URLs associated with this transcript item
  final List<String>? imageUrls;

  /// Timestamp when the transcript item was created
  final DateTime timestamp;

  /// Optional flag indicating if the item is a partial response
  final bool? isPartial;

  TranscriptItem({
    required this.id,
    required this.role,
    required this.content,
    this.imageUrls,
    required this.timestamp,
    this.isPartial,
  });

  factory TranscriptItem.fromJson(Map<String, dynamic> json) {
    final (textContent, imageUrls) =
        _extractContent(json['content'] as List<dynamic>? ?? []);
    return TranscriptItem(
      id: json['id'] as String,
      role: json['role'] as String,
      content: textContent,
      imageUrls: imageUrls,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isPartial: json['isPartial'] as bool? ?? false,
    );
  }

  /// Helper method to extract text and image URLs from the content list
  /// in a single pass.
  static (String, List<String>?) _extractContent(List<dynamic> content) {
    final textParts = <String>[];
    final imageUrls = <String>[];

    for (final block in content) {
      if (block is Map<String, dynamic>) {
        final type = block['type'] as String?;
        if ((type == 'text' || type == 'input_text') &&
            block.containsKey('text')) {
          final text = block['text'] as String?;
          if (text != null && text.isNotEmpty) {
            textParts.add(text);
          }
        } else if (type == 'image_url' && block.containsKey('image_url')) {
          final imageUrlMap = block['image_url'] as Map<String, dynamic>?;
          final url = imageUrlMap?['url'] as String?;
          if (url != null && url.isNotEmpty) {
            imageUrls.add(url);
          }
        }
      }
    }
    return (textParts.join(' '), imageUrls.isNotEmpty ? imageUrls : null);
  }

  /// Helper method to check if the transcript item contains images
  bool hasImages() {
    return imageUrls != null && imageUrls!.isNotEmpty;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        if (imageUrls != null) 'imageUrls': imageUrls,
        'timestamp': timestamp.toIso8601String(),
        'isPartial': isPartial ?? false,
      };

  @override
  String toString() =>
      'TranscriptItem(id: $id, role: $role, content: $content, imageUrls: $imageUrls, timestamp: $timestamp, isPartial: $isPartial)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TranscriptItem &&
        other.id == id &&
        other.role == role &&
        other.content == content &&
        other.imageUrls == imageUrls &&
        other.timestamp == timestamp &&
        other.isPartial == isPartial;
  }

  @override
  int get hashCode => Object.hash(id, role, content, imageUrls, timestamp, isPartial);
}
