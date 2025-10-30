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
