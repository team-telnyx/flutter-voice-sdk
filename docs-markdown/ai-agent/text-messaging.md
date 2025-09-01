# Sending Text Messages to AI Agents

## Overview

In addition to voice conversation, you can send text messages directly to the AI Agent during an active call. This allows for mixed-mode communication where users can both speak and type messages to the AI Assistant.

## Method Signature

```dart
void sendConversationMessage(String message)
```

This method is available on the `Call` object during an active AI Assistant conversation.

## Basic Usage

### Getting the Active Call

```dart
// Get the active call instance (after successfully connecting and calling)
Call? activeCall = _telnyxClient.calls.values.firstOrNull;

if (activeCall != null) {
  // Send a text message to the AI Agent
  activeCall.sendConversationMessage("Hello, can you help me with my account?");
}
```

### Retrieving Call by ID

```dart
// If you have the call ID
String callId = "your-call-id";
Call? call = _telnyxClient.getCallOrNull(callId);

if (call != null) {
  call.sendConversationMessage("I need assistance with billing.");
}
```

## Advanced Usage Examples

### Interactive Chat Interface

```dart
class AIChatInterface extends StatefulWidget {
  final Call aiCall;
  
  const AIChatInterface({required this.aiCall});

  @override
  _AIChatInterfaceState createState() => _AIChatInterfaceState();
}

class _AIChatInterfaceState extends State<AIChatInterface> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<TranscriptItem> _transcript = [];

  @override
  void initState() {
    super.initState();
    
    // Listen for transcript updates
    _telnyxClient.onTranscriptUpdate = (List<TranscriptItem> transcript) {
      setState(() {
        _transcript = transcript;
      });
      _scrollToBottom();
    };
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      // Send text message to AI agent
      widget.aiCall.sendConversationMessage(message);
      
      // Clear input field
      _messageController.clear();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Transcript display
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _transcript.length,
            itemBuilder: (context, index) {
              final item = _transcript[index];
              return _buildMessageBubble(item);
            },
          ),
        ),
        
        // Input field
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                onPressed: _sendMessage,
                icon: Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(TranscriptItem item) {
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
        child: Text(item.content),
      ),
    );
  }
}
```

### Predefined Quick Responses

```dart
class QuickResponseButtons extends StatelessWidget {
  final Call aiCall;
  
  const QuickResponseButtons({required this.aiCall});

  final List<String> quickResponses = const [
    "Yes, please continue",
    "No, that's not correct",
    "Can you repeat that?",
    "I need more information",
    "Thank you for your help",
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: quickResponses.map((response) {
        return ElevatedButton(
          onPressed: () {
            aiCall.sendConversationMessage(response);
          },
          child: Text(response),
        );
      }).toList(),
    );
  }
}
```

### Context-Aware Messaging

```dart
class ContextualMessageSender {
  final Call aiCall;
  
  ContextualMessageSender(this.aiCall);

  void sendUserInfo(Map<String, dynamic> userInfo) {
    final message = "User Information: ${jsonEncode(userInfo)}";
    aiCall.sendConversationMessage(message);
  }

  void sendErrorReport(String errorCode, String description) {
    final message = "Error Report - Code: $errorCode, Description: $description";
    aiCall.sendConversationMessage(message);
  }

  void sendFormData(Map<String, String> formData) {
    final formattedData = formData.entries
        .map((entry) => "${entry.key}: ${entry.value}")
        .join(", ");
    
    final message = "Form Data: $formattedData";
    aiCall.sendConversationMessage(message);
  }

  void sendLocationInfo(double latitude, double longitude) {
    final message = "Location: Latitude $latitude, Longitude $longitude";
    aiCall.sendConversationMessage(message);
  }
}

// Usage example
void handleUserAction() {
  final contextSender = ContextualMessageSender(activeCall);
  
  // Send user information
  contextSender.sendUserInfo({
    'user_id': '12345',
    'account_type': 'premium',
    'last_login': '2024-01-15'
  });
  
  // Send form data
  contextSender.sendFormData({
    'issue_category': 'billing',
    'priority': 'high',
    'description': 'Payment failed'
  });
}
```

## Message Formatting

### Rich Text Messages

```dart
class RichMessageSender {
  final Call aiCall;
  
  RichMessageSender(this.aiCall);

  void sendStructuredMessage({
    required String type,
    required String content,
    Map<String, dynamic>? metadata,
  }) {
    final message = {
      'type': type,
      'content': content,
      'metadata': metadata ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    aiCall.sendConversationMessage(jsonEncode(message));
  }

  void sendCommand(String command, Map<String, dynamic> parameters) {
    sendStructuredMessage(
      type: 'command',
      content: command,
      metadata: {'parameters': parameters},
    );
  }

  void sendQuery(String question, String category) {
    sendStructuredMessage(
      type: 'query',
      content: question,
      metadata: {'category': category},
    );
  }
}
```

### Message Templates

```dart
class MessageTemplates {
  static String greeting(String userName) {
    return "Hello, I'm $userName. How can you assist me today?";
  }

  static String issueReport(String issueType, String description) {
    return "Issue Report: Type - $issueType, Description - $description";
  }

  static String followUp(String previousTopic) {
    return "Following up on our previous discussion about $previousTopic";
  }

  static String clarification(String topic) {
    return "Can you provide more details about $topic?";
  }

  static String confirmation(String action) {
    return "Please confirm: $action";
  }
}

// Usage
void sendGreeting() {
  final message = MessageTemplates.greeting("John Doe");
  activeCall?.sendConversationMessage(message);
}
```

## Error Handling

```dart
class SafeMessageSender {
  final Call aiCall;
  
  SafeMessageSender(this.aiCall);

  bool sendMessage(String message) {
    try {
      // Validate message
      if (message.trim().isEmpty) {
        print('Cannot send empty message');
        return false;
      }

      // Check call state
      if (!aiCall.callState.isActive) {
        print('Cannot send message: call is not active');
        return false;
      }

      // Send message
      aiCall.sendConversationMessage(message);
      return true;
      
    } catch (e) {
      print('Failed to send message: $e');
      return false;
    }
  }

  bool sendMessageWithRetry(String message, {int maxRetries = 3}) {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      if (sendMessage(message)) {
        return true;
      }
      
      if (attempt < maxRetries) {
        print('Retry attempt $attempt failed, retrying...');
        // Wait before retry
        Future.delayed(Duration(seconds: 1));
      }
    }
    
    print('Failed to send message after $maxRetries attempts');
    return false;
  }
}
```

## Best Practices

### 1. Message Validation

```dart
bool isValidMessage(String message) {
  // Check length
  if (message.length > 1000) {
    return false; // Too long
  }
  
  // Check for empty or whitespace only
  if (message.trim().isEmpty) {
    return false;
  }
  
  // Check for inappropriate content (implement your own logic)
  if (containsInappropriateContent(message)) {
    return false;
  }
  
  return true;
}
```

### 2. Rate Limiting

```dart
class RateLimitedMessageSender {
  final Call aiCall;
  final int maxMessagesPerMinute;
  final List<DateTime> _messageTimes = [];
  
  RateLimitedMessageSender(this.aiCall, {this.maxMessagesPerMinute = 10});

  bool canSendMessage() {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(Duration(minutes: 1));
    
    // Remove old timestamps
    _messageTimes.removeWhere((time) => time.isBefore(oneMinuteAgo));
    
    return _messageTimes.length < maxMessagesPerMinute;
  }

  bool sendMessage(String message) {
    if (!canSendMessage()) {
      print('Rate limit exceeded. Please wait before sending another message.');
      return false;
    }

    aiCall.sendConversationMessage(message);
    _messageTimes.add(DateTime.now());
    return true;
  }
}
```

## Important Notes

- **AI Assistant Only**: The `sendConversationMessage` method is only available during AI Assistant conversations
- **Transcript Integration**: Text messages sent this way will appear in the transcript updates alongside spoken conversation
- **Processing**: The AI Agent will process and respond to text messages just like spoken input
- **Active Call Required**: You must have an active call established before sending text messages
- **Real-time**: Messages are sent in real-time and will be processed immediately by the AI agent

## Troubleshooting

### Message Not Sent

If messages aren't being sent:

1. Verify the call is active (`call.callState.isActive`)
2. Check that you're in an AI Assistant conversation (after `anonymousLogin`)
3. Ensure the call object is not null
4. Verify network connectivity

### Messages Not Appearing in Transcript

If sent messages don't appear in the transcript:

1. Confirm `onTranscriptUpdate` callback is properly set
2. Check that the message was successfully sent
3. Wait a moment for the transcript to update

## Next Steps

- [View complete example](complete-example.md) for full AI Agent implementation
- [Learn about transcript updates](transcript-updates.md) to handle responses
