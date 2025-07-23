# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Package Overview

This is the `telnyx_common` package - a high-level abstraction layer for the Telnyx Flutter Voice SDK. It provides a simplified, state-management agnostic interface for WebRTC voice calling that builds upon the lower-level `telnyx_webrtc` package. This package is currently under active development on branch WEBRTC-2823.

## Architecture

### Core Components

**Public API:**
- `TelnyxVoipClient` - Main entry point for all voice operations
- `TelnyxVoipClientConfig` - Configuration for initializing the client
- `PushNotificationManagerConfig` - Configuration for push notification handling

**Internal Architecture:**
- `SessionManager` - Manages WebSocket connection lifecycle and authentication
- `CallStateController` - Implements call state machine and transitions
- `CallKitAdapter` - Handles native UI integration (CallKit/ConnectionService)
- `PushNotificationGateway` - Manages push notification registration and handling
- `TelnyxSessionEventProcessor` - Processes WebRTC signaling events

**State Management:**
- Uses Dart Streams for reactive state updates
- Platform-agnostic design allows integration with any Flutter state management solution
- Emits `ConnectionState` and `CallState` changes via streams

### Key Design Principles
1. **Abstraction**: Hides WebRTC complexity behind a simple API
2. **State Management Agnostic**: Uses Streams instead of forcing a specific pattern
3. **Error Handling**: Comprehensive error states and recovery mechanisms
4. **Platform Support**: Unified API across Android, iOS, and Web

## Development Commands

```bash
# Run tests for this package
cd packages/telnyx_common && flutter test

# Analyze code
dart analyze

# Format code
dart format .

# Run specific test file
flutter test test/unit/session_manager_test.dart

# Run tests with coverage
flutter test --coverage
```

## Code Style and Conventions

- Follow Dart effective style guide
- Use meaningful variable and method names
- Keep methods focused and single-purpose
- Document public APIs with dartdoc comments
- Prefer composition over inheritance
- Use dependency injection for testability

## Testing Guidelines

- Write unit tests for all public methods
- Mock external dependencies (WebRTC, platform channels)
- Test state transitions thoroughly
- Include edge cases and error scenarios
- Aim for high code coverage (>80%)

## Integration with telnyx_webrtc

This package depends on and wraps the lower-level `telnyx_webrtc` package:
- Uses `TelnyxClient` for WebSocket communication
- Wraps `Call` objects with enhanced state management
- Handles push notification complexity internally
- Provides simplified error handling

## Push Notification Architecture

The package includes comprehensive push notification support:
- `PushNotificationGateway` - Central push handling
- Platform-specific implementations via method channels
- Automatic token registration on connection
- Simplified push call answering/declining

## State Flow

1. **Connection States**: `idle` → `connecting` → `connected` / `disconnected` / `error`
2. **Call States**: `idle` → `ringing` → `active` → `held` → `ended`
3. **Error Recovery**: Automatic reconnection with exponential backoff
4. **Push States**: Handles both foreground and background scenarios

## Important Implementation Notes

- Always dispose of the client when done to prevent memory leaks
- Push tokens are automatically registered on successful connection
- Call state changes are emitted via `callStateStream`
- Connection state changes are emitted via `connectionStateStream`
- The package handles CallKit/ConnectionService integration automatically

## Common Usage Patterns

```dart
// Initialize client
final client = TelnyxVoipClient(config);

// Listen to state changes
client.connectionStateStream.listen((state) => updateUI(state));
client.callStateStream.listen((call) => updateCallUI(call));

// Connect with credentials or token
await client.connect(credentials: myCredentials);
// or
await client.connect(token: myToken);

// Make a call
await client.call(destinationNumber: '+1234567890');

// Handle incoming calls
// Calls automatically appear via callStateStream

// Answer/Decline
await client.answer(callId);
await client.decline(callId);

// Dispose when done
client.dispose();
```

## Platform-Specific Considerations

**Android:**
- Requires `TelnyxPushService` to be registered in the manifest
- Firebase configuration needed for push notifications
- Permissions handled automatically by the package

**iOS:**
- Requires CallKit and PushKit entitlements
- APNS configuration for push notifications
- Microphone permissions in Info.plist

**Web:**
- Limited push notification support
- Falls back to polling for incoming calls
- Requires secure context (HTTPS)

## Debugging Tips

- Enable verbose logging: `TelnyxVoipClient.enableVerboseLogging = true`
- Check connection state before making calls
- Monitor `errorStream` for detailed error information
- Use `callQualityStream` to monitor call metrics
- Platform logs available via method channel responses