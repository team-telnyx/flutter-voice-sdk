# Sending Text Messages to AI Agents

## Overview

In addition to voice conversation, you can send text messages directly to the AI Agent during an active call. This allows for mixed-mode communication where users can both speak and type messages to the AI Assistant.

## Method Signature

```dart
void sendConversationMessage(String message, {String? base64Image})
```

This method is available on the `Call` object during an active AI Assistant conversation.

### Parameters

- `message` (String): The text message to send to the AI Agent
- `base64Image` (String?, optional): A base64 encoded image string for vision-capable AI models

**Note**: To provide images to your AI assistant, ensure you are using a vision-capable model. The `base64Image` parameter accepts either:
- A complete data URL format: `data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQ...`
- A raw base64 string (will be automatically formatted as JPEG): `/9j/4AAQSkZJRgABAQAAAQ...`

## Basic Usage

### Getting the Active Call

```dart
// Get the active call instance (after successfully connecting and calling)
Call? activeCall = _telnyxClient.calls.values.firstOrNull;

if (activeCall != null) {
  // Send a text message to the AI Agent
  activeCall.sendConversationMessage("Hello, can you help me with my account?");
  
  // Send a message with an image (for vision-capable models)
  activeCall.sendConversationMessage(
    "Can you analyze this image?", 
    base64Image: "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQ..."
  );
  
  // Send only an image without text
  activeCall.sendConversationMessage(
    "", 
    base64Image: "/9j/4AAQSkZJRgABAQAAAQ..." // Raw base64 (auto-formatted as JPEG)
  );
}
```

### Retrieving Call by ID

```dart
// If you have the call ID
String callId = "your-call-id";
Call? call = _telnyxClient.getCallOrNull(callId);

if (call != null) {
  call.sendConversationMessage("I need assistance with billing.");
  
  // Send with image for visual assistance
  call.sendConversationMessage(
    "Here's my billing statement, can you help explain this charge?",
    base64Image: base64EncodedBillingImage
  );
}
```

## Image Messaging with Vision-Capable Models

### Sending Images to AI Agents

The `sendConversationMessage` method now supports sending base64 encoded images to vision-capable AI models. This enables multimodal interactions where users can share visual content for analysis, description, or assistance.

### Image Encoding Example

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ImageMessageSender {
  final Call aiCall;
  
  ImageMessageSender(this.aiCall);

  /// Convert a file to base64 and send to AI agent
  Future<void> sendImageFile(File imageFile, String message) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      
      // Determine image format from file extension
      final extension = imageFile.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);
      
      final dataUrl = 'data:$mimeType;base64,$base64String';
      
      aiCall.sendConversationMessage(message, base64Image: dataUrl);
    } catch (e) {
      print('Error sending image: $e');
    }
  }

  /// Send image from Uint8List bytes
  void sendImageBytes(Uint8List imageBytes, String message, {String format = 'jpeg'}) {
    final base64String = base64Encode(imageBytes);
    final dataUrl = 'data:image/$format;base64,$base64String';
    
    aiCall.sendConversationMessage(message, base64Image: dataUrl);
  }

  /// Send image from asset
  Future<void> sendAssetImage(String assetPath, String message) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      
      sendImageBytes(bytes, message);
    } catch (e) {
      print('Error loading asset image: $e');
    }
  }

  String _getMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // Default fallback
    }
  }
}

// Usage example
void sendScreenshot() async {
  final imageSender = ImageMessageSender(activeCall);
  
  // Send from file
  final imageFile = File('/path/to/screenshot.png');
  await imageSender.sendImageFile(imageFile, "Can you help me understand what's shown in this screenshot?");
  
  // Send from asset
  await imageSender.sendAssetImage('assets/images/diagram.png', "Please explain this diagram");
}
```

### Camera Integration Example

```dart
import 'package:camera/camera.dart';

class CameraImageSender {
  final Call aiCall;
  late CameraController _controller;
  
  CameraImageSender(this.aiCall);

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(cameras.first, ResolutionPreset.medium);
    await _controller.initialize();
  }

  Future<void> captureAndSend(String message) async {
    try {
      final image = await _controller.takePicture();
      final bytes = await File(image.path).readAsBytes();
      final base64String = base64Encode(bytes);
      
      aiCall.sendConversationMessage(
        message, 
        base64Image: 'data:image/jpeg;base64,$base64String'
      );
    } catch (e) {
      print('Error capturing image: $e');
    }
  }

  void dispose() {
    _controller.dispose();
  }
}
```

### Image Validation and Optimization

```dart
class ImageValidator {
  static const int maxFileSizeBytes = 4 * 1024 * 1024; // 4MB
  static const List<String> supportedFormats = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

  static bool isValidImageFile(File file) {
    // Check file size
    if (file.lengthSync() > maxFileSizeBytes) {
      print('Image file too large. Maximum size: ${maxFileSizeBytes / (1024 * 1024)}MB');
      return false;
    }

    // Check file extension
    final extension = file.path.split('.').last.toLowerCase();
    if (!supportedFormats.contains(extension)) {
      print('Unsupported image format. Supported: ${supportedFormats.join(', ')}');
      return false;
    }

    return true;
  }

  static Future<Uint8List?> compressImage(Uint8List imageBytes, {int quality = 85}) async {
    // Implementation would depend on your image processing library
    // This is a placeholder for image compression logic
    return imageBytes;
  }
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
- **Vision Models**: Base64 image support requires vision-capable AI models to be configured in your AI Assistant
- **Image Formats**: Supported image formats include JPEG, PNG, GIF, and WebP
- **Image Size**: Consider image file size and compression for optimal performance
- **Multimodal**: You can send text and images together, or send images without text for pure visual analysis

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

- [Learn about transcript updates](https://developers.telnyx.com/development/webrtc/flutter-sdk/ai-agent/transcript-updates) to handle responses
