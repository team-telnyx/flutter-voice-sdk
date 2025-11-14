# AI Agent Usage

The Flutter Voice SDK supports [Voice AI Agent](https://telnyx.com/products/voice-ai-agents) implementations. 

To get started, follow the steps [described here](https://telnyx.com/resources/ai-assistant-builder) to build your first AI Assistant. 

Once your AI Agent is up and running, you can use the SDK to communicate with your AI Agent with the following steps:

## Pre-developed AI Widget

If you don't want to develop your own custom AI Agent interface from scratch, you can utilize our pre-developed AI Agent widget that provides a drop-in solution for voice AI interactions.

### Flutter Telnyx Voice AI Widget

The **Flutter Telnyx Voice AI Widget** is a standalone, embeddable widget that provides a complete voice AI assistant interface using the Telnyx WebRTC SDK.

**Repository**: [https://github.com/team-telnyx/flutter-telnyx-voice-ai-widget](https://github.com/team-telnyx/flutter-telnyx-voice-ai-widget)

**Package**: [https://pub.dev/packages/flutter_telnyx_voice_ai_widget](https://pub.dev/packages/flutter_telnyx_voice_ai_widget)

### Key Features

- **Configurable Dimensions**: Set custom height and width for the widget
- **Icon-Only Mode**: Floating action button-style interface for minimal UI footprint
- **Multiple UI States**: Collapsed, connecting, expanded, and conversation views
- **Agent Status Indicators**: Shows when the agent is thinking or waiting for interruption
- **Audio Visualizer**: Animated bars that respond to call activity
- **Theme Support**: Light and dark theme configurations
- **Call Controls**: Built-in mute/unmute and end call functionality
- **Conversation View**: Full transcript with message history
- **Responsive Design**: Adapts to different screen sizes

### Quick Integration

```dart
import 'package:flutter_telnyx_voice_ai_widget/flutter_telnyx_voice_ai_widget.dart';

// Basic usage
TelnyxVoiceAiWidget(
  height: 60,
  width: 300,
  assistantId: 'your-assistant-id',
)

// Icon-only mode
TelnyxVoiceAiWidget.iconOnly(
  assistantId: 'your-assistant-id',
)
```

This widget handles all the complexity of AI Agent integration, providing a production-ready solution that you can customize to match your app's design.

## Documentation Structure

This directory contains detailed documentation for AI Agent integration:

- [Anonymous Login](https://developers.telnyx.com/development/webrtc/flutter-sdk/ai-agent/anonymous-login) - How to connect to AI assistants without traditional authentication
- [Starting Conversations](https://developers.telnyx.com/development/webrtc/flutter-sdk/ai-agent/starting-conversations) - How to initiate calls with AI assistants
- [Transcript Updates](https://developers.telnyx.com/development/webrtc/flutter-sdk/ai-agent/transcript-updates) - Real-time conversation transcripts
- [Text Messaging](https://developers.telnyx.com/development/webrtc/flutter-sdk/ai-agent/text-messaging) - Send text messages to AI agents during calls

## Quick Start

1. **Login**: Use `anonymousLogin()` to connect to your AI assistant
2. **Call**: Use `newInvite()` to start a conversation (destination ignored)
3. **Listen**: Set up `onTranscriptUpdate` callback for real-time transcripts
4. **Message**: Use `sendConversationMessage()` to send text during calls

## Important Notes

- AI Agent features are only available after `anonymousLogin`
- All calls after anonymous login are routed to the specified AI assistant
- Transcript updates are real-time and include both user and assistant messages
- Text messages appear in transcript updates alongside spoken conversation
- Standard call controls (mute, hold, end) work with AI agent calls
