# Anonymous Login for AI Agents

## Overview

The `anonymousLogin` method allows you to connect to AI assistants without traditional authentication credentials. This is the first step in establishing communication with a Telnyx AI Agent.

## Method Signature

```dart
Future<void> anonymousLogin({
  required String targetId,
  String targetType = 'ai_assistant',
  String? targetVersionId,
  Map<String, dynamic>? userVariables,
  bool reconnection = false,
  LogLevel logLevel = LogLevel.none,
})
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `targetId` | String | Yes | - | The ID of your AI assistant |
| `targetType` | String | No | 'ai_assistant' | The type of target |
| `targetVersionId` | String? | No | null | Optional version ID of the target. If not provided, uses latest version |
| `userVariables` | Map<String, dynamic>? | No | null | Optional user variables to include |
| `reconnection` | bool | No | false | Whether this is a reconnection attempt |
| `logLevel` | LogLevel | No | LogLevel.none | Log level for this session |

## Usage Example

```dart
try {
  await _telnyxClient.anonymousLogin(
    targetId: 'your_assistant_id',
    // targetType: 'ai_assistant', // This is the default value
    // targetVersionId: 'your_assistant_version_id' // Optional
  );
  // You are now connected and can make a call to the AI Assistant.
} catch (e) {
  // Handle login error
  print('Login failed: $e');
}
```

## Advanced Usage

### With User Variables

```dart
await _telnyxClient.anonymousLogin(
  targetId: 'your_assistant_id',
  userVariables: {
    'user_id': '12345',
    'session_context': 'support_chat',
    'language': 'en-US'
  }
);
```

### With Logging

```dart
await _telnyxClient.anonymousLogin(
  targetId: 'your_assistant_id',
  logLevel: LogLevel.debug
);
```

## Important Notes

- **Call Routing**: After a successful `anonymousLogin`, any subsequent call, regardless of the destination, will be directed to the specified AI Assistant
- **Session Lock**: The session becomes locked to the AI assistant until disconnection
- **Version Control**: If `targetVersionId` is not provided, the SDK will use the latest available version
- **Error Handling**: Always wrap the call in a try-catch block to handle authentication errors

## Error Handling

Common errors you might encounter:

```dart
try {
  await _telnyxClient.anonymousLogin(targetId: 'invalid_id');
} catch (e) {
  if (e.toString().contains('authentication')) {
    // Handle authentication error
    print('Invalid assistant ID or authentication failed');
  } else if (e.toString().contains('network')) {
    // Handle network error
    print('Network connection failed');
  } else {
    // Handle other errors
    print('Unexpected error: $e');
  }
}
```

## Next Steps

After successful anonymous login:
1. [Start a conversation](https://developers.telnyx.com/development/webrtc/flutter-sdk/ai-agent/starting-conversations) using `newInvite()`
2. [Set up transcript updates](https://developers.telnyx.com/development/webrtc/flutter-sdk/ai-agent/transcript-updates) to receive real-time conversation data
3. [Send text messages](https://developers.telnyx.com/development/webrtc/flutter-sdk/ai-agent/text-messaging) during active calls
