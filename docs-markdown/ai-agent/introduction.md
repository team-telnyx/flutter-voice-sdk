# AI Agent Usage

The Flutter Voice SDK supports [Voice AI Agent](https://telnyx.com/products/voice-ai-agents) implementations. 

To get started, follow the steps [described here](https://telnyx.com/resources/ai-assistant-builder) to build your first AI Assistant. 

Once your AI Agent is up and running, you can use the SDK to communicate with your AI Agent with the following steps:

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
