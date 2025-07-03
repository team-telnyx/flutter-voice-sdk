# Changelog

All notable changes to the telnyx_common package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-07-03

### Added
- Initial implementation of telnyx_common package
- **Phase 1: Core Engine & Headless Operation**
  - TelnyxVoipClient public facade with state-agnostic API
  - SessionManager for TelnyxClient connection lifecycle management
  - CallStateController as central state machine for call management
  - Call model with reactive streams for state management
  - ConnectionState and CallState enums for simplified state handling
  - CredentialConfig and TokenConfig for authentication
  - Comprehensive unit tests for core functionality
  - Headless example application for testing and demonstration
- **Phase 2: Native UI Integration (Infrastructure Ready)**
  - CallKitAdapter for flutter_callkit_incoming integration
  - PushNotificationGateway for unified push notification handling
  - Native call UI support infrastructure
- State management agnostic design using Dart Streams
- Support for multiple simultaneous calls
- Reactive call control (mute, hold, DTMF, hangup)
- Error handling and connection state management
- Comprehensive documentation and examples

### Technical Details
- Built on top of telnyx_webrtc package
- Uses flutter_callkit_incoming for native UI (Phase 2)
- Implements adapter pattern for third-party dependency isolation
- Follows architectural patterns from Android telnyx_common module
- Supports both credential and token-based authentication
- Provides streams for connection state, calls list, and active call
- Includes proper resource cleanup and disposal methods

### Development Status
- ✅ Phase 1: Core Engine & Headless Operation (Complete)
- 🚧 Phase 2: Native UI Integration (Infrastructure Ready)
- 📋 Phase 3: Robustness & Background Processing (Planned)