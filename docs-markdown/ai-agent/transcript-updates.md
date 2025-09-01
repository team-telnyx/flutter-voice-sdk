# Real-time Transcript Updates

## Overview

During an AI Assistant conversation, the SDK provides real-time transcript updates that include both the caller's speech and the AI Assistant's responses. This allows you to display a live conversation transcript in your application.

## Setting Up Transcript Updates

To receive transcript updates, set up the `onTranscriptUpdate` callback on your `TelnyxClient` instance:

```dart
_telnyxClient.onTranscriptUpdate = (List<TranscriptItem> transcript) {
  // Handle the updated transcript
  for (var item in transcript) {
    print('${item.role}: ${item.content}');
    // item.role will be either 'user' or 'assistant'
    // item.content contains the spoken text
    // item.timestamp contains when the message was received
  }
  
  // Update your UI to display the conversation
  setState(() {
    _conversationTranscript = transcript;
  });
};
```

## TranscriptItem Properties

The `TranscriptItem` class contains the following properties:

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier for the transcript item |
| `role` | String | Either 'user' (for the caller) or 'assistant' (for the AI Agent) |
| `content` | String | The transcribed text content |
| `timestamp` | DateTime | When the transcript item was created |

## Manual Transcript Management

### Retrieving Current Transcript

You can manually retrieve the current transcript at any time:

```dart
List<TranscriptItem> currentTranscript = _telnyxClient.transcript;

// Process the transcript
for (var item in currentTranscript) {
  print('${item.timestamp}: [${item.role}] ${item.content}');
}
```

### Clearing Transcript

To clear the transcript (for example, when starting a new conversation):

```dart
_telnyxClient.clearTranscript();
```

## UI Implementation Examples

### Simple List View

```dart
class TranscriptWidget extends StatefulWidget {
  @override
  _TranscriptWidgetState createState() => _TranscriptWidgetState();
}

class _TranscriptWidgetState extends State<TranscriptWidget> {
  List<TranscriptItem> _transcript = [];

  @override
  void initState() {
    super.initState();
    
    // Set up transcript updates
    _telnyxClient.onTranscriptUpdate = (List<TranscriptItem> transcript) {
      setState(() {
        _transcript = transcript;
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _transcript.length,
      itemBuilder: (context, index) {
        final item = _transcript[index];
        return ListTile(
          leading: Icon(
            item.role == 'user' ? Icons.person : Icons.smart_toy,
            color: item.role == 'user' ? Colors.blue : Colors.green,
          ),
          title: Text(item.content),
          subtitle: Text(
            '${item.role} • ${item.timestamp.toString()}',
            style: TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }
}
```

### Chat Bubble Style

```dart
class ChatTranscriptWidget extends StatefulWidget {
  @override
  _ChatTranscriptWidgetState createState() => _ChatTranscriptWidgetState();
}

class _ChatTranscriptWidgetState extends State<ChatTranscriptWidget> {
  List<TranscriptItem> _transcript = [];
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    _telnyxClient.onTranscriptUpdate = (List<TranscriptItem> transcript) {
      setState(() {
        _transcript = transcript;
      });
      
      // Auto-scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _transcript.length,
      itemBuilder: (context, index) {
        final item = _transcript[index];
        final isUser = item.role == 'user';
        
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser ? Colors.blue[100] : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.content,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm:ss').format(item.timestamp),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
```

## Real-time Processing

### Filtering Transcript Items

```dart
_telnyxClient.onTranscriptUpdate = (List<TranscriptItem> transcript) {
  // Filter only user messages
  List<TranscriptItem> userMessages = transcript
      .where((item) => item.role == 'user')
      .toList();
  
  // Filter only assistant messages
  List<TranscriptItem> assistantMessages = transcript
      .where((item) => item.role == 'assistant')
      .toList();
  
  // Process latest message
  if (transcript.isNotEmpty) {
    TranscriptItem latestMessage = transcript.last;
    if (latestMessage.role == 'assistant') {
      // Handle new assistant response
      _handleAssistantResponse(latestMessage);
    }
  }
};
```

### Saving Transcript Data

```dart
class TranscriptManager {
  static const String _storageKey = 'conversation_transcripts';
  
  static Future<void> saveTranscript(
    String conversationId,
    List<TranscriptItem> transcript,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Convert to JSON
    List<Map<String, dynamic>> transcriptJson = transcript
        .map((item) => {
              'id': item.id,
              'role': item.role,
              'content': item.content,
              'timestamp': item.timestamp.toIso8601String(),
            })
        .toList();
    
    // Save to storage
    Map<String, dynamic> allTranscripts = 
        jsonDecode(prefs.getString(_storageKey) ?? '{}');
    allTranscripts[conversationId] = transcriptJson;
    
    await prefs.setString(_storageKey, jsonEncode(allTranscripts));
  }
  
  static Future<List<TranscriptItem>?> loadTranscript(
    String conversationId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> allTranscripts = 
        jsonDecode(prefs.getString(_storageKey) ?? '{}');
    
    if (!allTranscripts.containsKey(conversationId)) return null;
    
    List<dynamic> transcriptJson = allTranscripts[conversationId];
    return transcriptJson.map((item) => TranscriptItem(
      id: item['id'],
      role: item['role'],
      content: item['content'],
      timestamp: DateTime.parse(item['timestamp']),
    )).toList();
  }
}
```

## Important Notes

- **AI Assistant Only**: Transcript updates are only available during AI Assistant conversations initiated through `anonymousLogin`
- **Real-time Updates**: Transcripts are updated in real-time as the conversation progresses
- **Persistent**: The transcript persists throughout the call duration
- **Memory Management**: Consider clearing transcripts for long conversations to manage memory
- **Text Messages**: Text messages sent via `sendConversationMessage` also appear in the transcript

## Troubleshooting

### No Transcript Updates

If you're not receiving transcript updates:

1. Ensure you're using `anonymousLogin` (not regular authentication)
2. Verify the `onTranscriptUpdate` callback is set before starting the call
3. Check that the AI assistant is properly configured for transcription
4. Confirm the call is active and connected

### Missing Messages

If some messages are missing from the transcript:

1. Check network connectivity during the call
2. Ensure the callback isn't being overridden
3. Verify the AI assistant is configured to provide transcripts

## Next Steps

- [Send text messages](text-messaging.md) to the AI agent during calls
- [View complete example](complete-example.md) for full implementation
