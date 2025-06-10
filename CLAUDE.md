# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Telnyx Flutter Voice SDK - a WebRTC-based voice calling solution for Flutter applications supporting Android, iOS, and Web platforms. The project consists of a demo application and the core `telnyx_webrtc` package.

## Code Style
- Please reference the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style) for general Dart coding conventions.

## Workflow
- Don't change the verto message json structure without confirming first.
- When making changes to the SDK, ensure that you update the demo application accordingly to demonstrate the new functionality.
- Follow the established architecture patterns for WebRTC, including peer connection management, ICE candidate handling, and call state management.
- Ensure that all new features and bug fixes are accompanied by appropriate unit tests in the `telnyx_webrtc` package.
- If asked to make a pull request, ensure you use the format described at .github/PULL_REQUEST_TEMPLATE.md, including a clear description of the changes, any relevant issue numbers, and testing instructions.
- Please run 'dart format .' before committing any changes to ensure code style consistency.
- Please run 'dart analyze' to check for any static analysis issues before committing changes.
- Please do not update pubspec.yaml files without confirming the changes with the team first, especially for the `telnyx_webrtc` package.

## Development Commands

### Building and Running
```bash
# Run the demo app
flutter run

# Build for specific platforms
flutter build apk                    # Android APK
flutter build appbundle            # Android App Bundle
flutter build ios                  # iOS
flutter build web                  # Web

# Run tests
flutter test                        # Unit tests
flutter test integration_test/     # Integration tests

# Run with specific device
flutter run -d chrome              # Web browser
flutter run -d <device-id>         # Specific device
```

### Development Tools
```bash
# Install dependencies
flutter pub get

# Generate code (if using build_runner)
flutter packages pub run build_runner build

# Analyze code
dart analyze

# Format code
dart format .

# Clean build artifacts
flutter clean
```

### Testing
```bash
# Run unit tests in the SDK package
cd packages/telnyx_webrtc && flutter test

# Run integration tests using Patrol
flutter test integration_test/patrol_test.dart
```

## Architecture Overview

### Project Structure
- `/lib/` - Demo application code
- `/packages/telnyx_webrtc/` - Core SDK package
- `/android/` & `/ios/` - Platform-specific configurations
- `/docs-markdown/` - API documentation

### Core SDK Architecture (`packages/telnyx_webrtc/`)

**Main Classes:**
- `TelnyxClient` - Primary SDK entry point for connection management
- `Call` - Call control and state management  
- `TxSocket` - WebSocket communication layer
- `Peer` - WebRTC peer connection management

**Key Components:**
- **Config System**: `CredentialConfig` and `TokenConfig` for authentication
- **Message Handling**: Verto protocol implementation for signaling
- **Push Notifications**: Platform-specific push notification handling
- **Call Quality**: Real-time metrics collection and MOS calculation
- **Logging**: Configurable logging system with custom logger support

### Demo App Architecture (`/lib/`)

**State Management:**
- Provider pattern with `TelnyxClientViewModel` and `ProfileProvider`
- Separation of concerns between UI and business logic

**Push Notification System:**
- Platform-specific handlers: `AndroidPushNotificationHandler`, `IosPushNotificationHandler`
- Unified interface through `PlatformPushService`
- Integration with Firebase (Android) and APNS (iOS)

**Key Features:**
- Background/foreground state management
- CallKit integration (iOS)
- Firebase Cloud Messaging (Android)
- Profile management for multiple SIP credentials

### Platform-Specific Considerations

**Android:**
- Firebase integration required for push notifications
- Permissions: `INTERNET`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`
- Uses `flutter_callkit_incoming` for call UI

**iOS:**
- APNS and CallKit integration
- Microphone permission required in Info.plist
- PushKit for VoIP notifications

**Web:**
- Conditional imports for web-specific implementations
- WebRTC browser compatibility considerations

### WebRTC Flow
1. Authentication via `TelnyxClient.connectWithToken()` or `connectWithCredential()`
2. WebSocket connection established through `TxSocket`
3. SIP signaling via Verto protocol messages
4. WebRTC peer connection setup through `Peer` class
5. Media stream handling and call state management

### Configuration Files
- `pubspec.yaml` - Main app dependencies including Firebase, CallKit, and audio packages
- `packages/telnyx_webrtc/pubspec.yaml` - Core SDK dependencies (WebRTC, connectivity, audio)
- Platform-specific manifests for permissions and capabilities