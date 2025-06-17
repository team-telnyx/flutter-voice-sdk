enum CallDirection {
  incoming,
  outgoing,
}

class CallHistoryEntry {
  final String id;
  final String destination;
  final String? displayName;
  final CallDirection direction;
  final DateTime timestamp;
  final bool wasAnswered;

  CallHistoryEntry({
    required this.id,
    required this.destination,
    this.displayName,
    required this.direction,
    required this.timestamp,
    this.wasAnswered = false,
  });

  factory CallHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CallHistoryEntry(
      id: json['id'] as String,
      destination: json['destination'] as String,
      displayName: json['displayName'] as String?,
      direction: CallDirection.values[json['direction'] as int],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      wasAnswered: json['wasAnswered'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination': destination,
      'displayName': displayName,
      'direction': direction.index,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'wasAnswered': wasAnswered,
    };
  }

  String get displayDestination {
    return displayName?.isNotEmpty == true ? displayName! : destination;
  }

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}