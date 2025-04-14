## [1.1.2](https://pub.dev/packages/telnyx_webrtc/versions/1.1.2) (2025-04-09)

### Bug Fixing

- CodecError fix. Enhanced Ice Candidate Collection when answering calls to ensure more suitable candidates are used in the SDP.


## [1.1.1](https://pub.dev/packages/telnyx_webrtc/versions/1.1.1) (2025-03-25)

### Enhancement

- Added timemout for reconnection logic.

## [1.1.0](https://pub.dev/packages/telnyx_webrtc/versions/1.1.0) (2025-02-26)

### Enhancement

- Added method to disable push notifications on the SDK via `disablePushNotifications` method.
- Added a new parameter to the login configuration that allows users to provide their own `CustomLogger` to the SDK. This is useful for users that want to log the SDK's output in their own way or redirect logs to a server.
- Added a new CallStates 'dropped' and 'reconnecting' to the `CallState` enum. This will allow users to know when a call has been dropped or is in the process of reconnecting. There will be a `NetworkReason` provided for both of these states to give more context on why the call was dropped or is reconnecting.

## [1.0.2](https://pub.dev/packages/telnyx_webrtc/versions/1.0.2) (2025-02-14)

### Bug Fixing

- Fixed an issue where the call states were not being updated correctly, identifying a call as active when it was still connecting (ICE Gathering). This caused a scenario where users thought a call was active but couldn't hear anything. 

## [1.0.1](https://pub.dev/packages/telnyx_webrtc/versions/1.0.1) (2025-02-10)

### Bug Fixing

- Fixed an issue where running stats on calls could cause a call to end if the description was not set.
- Fixed the web version of the SDK that was having issues working on Safari. 

## [1.0.0](https://pub.dev/packages/telnyx_webrtc/versions/1.0.0) (2025-01-29)

### Enhancement - Breaking Changes

- Call ID no longer required when ending call or using DTMF. As these methods belong to a call
  object, the call ID is inferred from the call object itself. This means users only need to keep
  track of the call objects that are in use and call the relevant methods on the call object itself.

### Bug Fixing

- Fixed an issue where the Bye Params (such as cause = USER_BUSY) were not being included in the ReceivedMessage.

## [0.1.4](https://pub.dev/packages/telnyx_webrtc/versions/0.1.4) (2025-01-28)

### Enhancement

- Update UUID dependency to latest version to avoid conflicts with implementers of the SDK

## [0.1.3](https://pub.dev/packages/telnyx_webrtc/versions/0.1.3) (2025-01-06)

### Enhancement

- Updated WebRTC to latest Flutter WebRTC version containing a hotfix for audio route issues on iOS

### Bug Fixing

- Fixed an issue where audio would not loop for ringtones or ringback tones

## [0.1.2](https://pub.dev/packages/telnyx_webrtc/versions/0.1.2) (2024-12-20)

### Bug Fixing

- Fixed an issue where, when accepting a an invite, the destination number was being set to name
  instead of number.

## [0.1.1](https://pub.dev/packages/telnyx_webrtc/versions/0.1.1) (2024-12-12)

### Enhancement

- Improve IceCandidate handling to skip candidates when call is active
- Improve PushNotification support on callkit for iOS

### Bug Fixing

- General bug fixes and import cleanups.

## [0.1.0](https://pub.dev/packages/telnyx_webrtc/versions/0.1.0) (2024-11-07)

### Enhancement

- Implemented WebSocket and RTC peer reconnection logic to ensure seamless recovery during network
  disconnects or switches.

## [0.0.18](https://pub.dev/packages/telnyx_webrtc/versions/0.0.18) (2024-09-25)

### Bug Fixing

- General bug fixes related to imports and how they work and switch between Mobile / Web

## [0.0.17](https://pub.dev/packages/telnyx_webrtc/versions/0.0.17) (2024-08-12)

### Feature

- Added support to include login credentials for the `connect` method.

## [0.0.16](https://pub.dev/packages/telnyx_webrtc/versions/0.0.16) (2024-08-01)

### Feature

- Implemented push notifications mechanism for both background and foreground states.

### Bug Fixing

- Fixed one-way audio issue.
- Enhanced call state handling mechanism.

## [0.0.15](https://pub.dev/packages/telnyx_webrtc/versions/0.0.15) (2024-06-27)

### Bug Fixing

- Fixed disposal of audio tracks to release iOS/Android microphones properly.

## [0.0.14](https://pub.dev/packages/telnyx_webrtc/versions/0.0.14) (2024-03-20)

### Bug Fixing

- Fixed iOS push notification handling and reliability.

## [0.0.13](https://pub.dev/packages/telnyx_webrtc/versions/0.0.13) (2024-03-07)

### Bug Fixing

- Resolved issues with Android push notifications.

## [0.0.12](https://pub.dev/packages/telnyx_webrtc/versions/0.0.12) (2024-02-27)

### Bug Fixing

- Fixed audio issues for the web platform.

## [0.0.11](https://pub.dev/packages/telnyx_webrtc/versions/0.0.11) (2024-02-07)

### Bug Fixing

- Fixed ringing state behavior.

## [0.0.10](https://pub.dev/packages/telnyx_webrtc/versions/0.0.10) (2024-01-04)

### Bug Fixing

- Fixed gateway timeout issues.

## [0.0.9](https://pub.dev/packages/telnyx_webrtc/versions/0.0.9) (2022-10-22)

### Feature

- Updated the sample app with a new disconnect functionality.

### Bug Fixing

- Fixed disconnect functionality to allow subsequent logins.

## [0.0.8](https://pub.dev/packages/telnyx_webrtc/versions/0.0.8) (2022-10-05)

### Enhancement

- Added Ping/Pong socket functionality to keep sockets alive.

### Bug Fixing

- Fixed serialized variable names for better backend functionality.
- Improved code formatting for readability.

## [0.0.7](https://pub.dev/packages/telnyx_webrtc/versions/0.0.7) (2022-09-21)

### Bug Fixing

- General bug fixes.
- Improved code formatting for readability.

## [0.0.6](https://pub.dev/packages/telnyx_webrtc/versions/0.0.6) (2022-09-05)

### Feature

- Enabled speaker mode toggle.

## [0.0.5](https://pub.dev/packages/telnyx_webrtc/versions/0.0.5) (2022-09-02)

### Feature

- Enabled PSTN call integration using early SDP contained in Telnyx media messages.

### Bug Fixing

- Fixed ICE candidate error that would add a local IP ICE candidate.

## [0.0.4](https://pub.dev/packages/telnyx_webrtc/versions/0.0.4) (2022-08-26)

### Bug Fixing

- Improved stability by providing a session ID to the backend immediately rather than waiting to set
  one.
- Fixed gateway retry errors that continuously retried without a timeout.

## [0.0.3](https://pub.dev/packages/telnyx_webrtc/versions/0.0.3) (2022-08-03)

### Enhancement

- Improved SDK stability with regular black-box tests.
- Included an example folder with documentation.

### Bug Fixing

- Resolved issues from static code analysis.

## [0.0.2](https://pub.dev/packages/telnyx_webrtc/versions/0.0.2) (2022-07-22)

### Enhancement

- Simplified SDK usage by removing unnecessary parameters from various calls.
- Added reference links for Pub.dev listing.

## [0.0.1](https://pub.dev/packages/telnyx_webrtc/versions/0.0.1) (2022-07-18)

### Initial Release

- Initial release with basic functionality.