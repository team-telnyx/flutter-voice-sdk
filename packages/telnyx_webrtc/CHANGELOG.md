## [4.0.1](https://pub.dev/packages/telnyx_webrtc/versions/4.0.1) (2026-02-12)
### Bug Fixing
- fix web outbound calling and build by including answered device token and improved SDP handling 

## [4.0.0](https://pub.dev/packages/telnyx_webrtc/versions/4.0.0) (2026-02-05)
### Breaking
- Using version 4.0.0 will adjust how Push Notifications are handled on iOS devices. Using 4.0.0 allows iOS devices to received `MISSED CALL` notifications - signifying that a call was either missed, or an existing ongoing invitation that was not yet reacted to has been cancelled. Please make sure you are handling these `MISSED CALL` notifications appropriately if necessary or don't update. 

### Bug Fixing
- Align jitter source with Android/iOS Native SDKs for consistent MOS calculation when using Stats.

### Enhancement
- Send an answered `answered_device_token` parameter for push notification calls, allowing us to send `MISSED CALL` notifications to all registered devices except the one that answered if users are using multiple devices

## [3.4.2](https://pub.dev/packages/telnyx_webrtc/versions/3.4.2) (2026-01-15)
### Bug Fixing
- Fixed an issue where `CallState.active` was not called for outbound calls, and users could only rely on `SocketMethod.answer` to determine when a call was active.

## [3.4.1](https://pub.dev/packages/telnyx_webrtc/versions/3.4.1) (2026-01-09)
### Bug Fixing
- Fixed an issue where the Web peer class did not match the mobile peer class causing build errors on Web and breaking the initial mute state of the call.

## [3.4.0](https://pub.dev/packages/telnyx_webrtc/versions/3.4.0) (2026-01-08)
### Enhancement
- Added `Trickle Ice` option on `newInvite` and `acceptCall` methods to allow users to enable or disable Trickle ICE for calls. By default, Trickle ICE is disabled.
- Added Call Connection Time Benchmarking to measure the time taken to establish a call connection. This can be useful for performance monitoring and optimization, and is logged automatically when a call is connected.

### Bug Fixing
- Adjustments to Call Connection Establishment logic resulting from Connection Time Benchmark findings to improve call setup times and reliability.

## [3.3.0](https://pub.dev/packages/telnyx_webrtc/versions/3.3.0) (2025-12-15)
### Enhancement
- Added `EchoCanellation`, `NoiseSuppression` and `AutoGainControl` MediaConstraints as AudioConstraints that can be passed on `newInvite` and `acceptCall`
- Added a new parameter on `newInvite` and `acceptCall` called `mutedMicOnStart`, allowing users to join a call muted.
- Added `tx_server_configuration.dart` allowing users to specify a specific server connection including host, port, turn and stun. 

### Bug Fixing
- Further tweaking and refining of the Ice Candidate Gathering and Peer disposal logic to improve call quality and memory usage

## [3.2.0](https://pub.dev/packages/telnyx_webrtc/versions/3.2.0) (2025-11-18)
### Enhancement
- AI Agent Conversation Message Enhancements
  - Added support for sending multiple Base64 encoded images via the `sendConversationMessage()` method on the Call object. This allows users to send images to the AI agent for analysis or context during conversations.
- Added configurable push notification timeout parameter on the  `Config ` class. This allows users to specify how long the SDK should wait for a push notification to be accepted before timing out. The default value is 10 seconds.
  - Additionally, the timeout can be configured per call via the  `pushAnswerTimeoutMs ` parameter on the  `handlePushNotification() ` method. This will override the global timeout set in the Config class for that specific call.

### Bug Fixing
- Fixed an issue where speakerphone state was not persisted after reconnection on Android devices. Now, the speakerphone state will be maintained correctly after network interruptions and reconnections.

## [3.1.0](https://pub.dev/packages/telnyx_webrtc/versions/3.1.0) (2025-10-20)
### Enhancement

- Socket Connection Quality Callback
    - Added OnConnectionMetricsUpdate callback to the TelnyxClient class to provide real-time updates on the quality of the WebSocket connection. This can help users monitor and respond to network conditions affecting call quality.
- AI Agent Enhancements
  - Allow for Base64 encoded images that can be sent via sendConversationMessage() on the Call object. 
- ICE Candidate Renegotiation process implemented to enhance call stability during network changes.
- Supported Codecs no longer return a static list of codecs, but instead will return the actual codecs supported by the current device.

### Bug Fixing
- Fixed an issue where preferred codecs were not being respected when specified during call initiation.
- Fixed how stat metrics were being calculated and sent via the socket, causing some graphs during the debug view to be missing
- Fixed an issue where the SDK version was not being parsed correctly in release builds, causing issues with backend logging and debugging.

## [3.0.0](https://pub.dev/packages/telnyx_webrtc/versions/3.0.0) (2025-08-25)
### Enhancement

- Added support for AI Agent Usage.
  - Login to your specific AI agent by providing the agent ID from the portal to the anonymous login method.
  - Any call made via the newInvite method will be routed to the AI agent.
  - Transcription and AI responses will be available via the onTranscriptUpdate callback
- Added PreferredCodec parameter to the newInvite and acceptCall methods to allow users to specify their preferred audio codec for the call. Note that if the chosen codec is not supported, the call will default to the first codec supported in the SDP. 
  - You can retrieve the list of supported codecs via the getSupportedAudioCodecs method on the TelnyxClient class, however for now these are static and it is possible that some devices may not support all codecs listed - the SDK will fallback to a supported codec in this case.
  
### Bug Fixing
- Fixed an issue where log levels were not being respected with the default logger (Specifically the NONE log level). Now, the default logger will respect the log level set in the Config class.
- Fixed an issue where, for Android, the default speakerphone state was enabled when a call was initiated. Now, the speakerphone will only be enabled if the user explicitly enables it.

## [2.0.1](https://pub.dev/packages/telnyx_webrtc/versions/2.0.1) (2025-06-26)
### Enhancement

- Added Region Selection support as a parameter on the Config class. This allows users to specify the region for their WebSocket connection, enhancing performance and reliability based on geographical location. It will default to 'auto' if not specified, which will automatically select the best region based on the user's location. There is also a fallbackOnRegionFailure parameter that defaults to true, which will automatically fallback to the 'auto' region if the specified region fails to connect if set to true. 
- Added a 10 second answer timeout for accepted push notifications. This ensures that if a user accepts a push notification but does not receive an invite on the socket once connected within 10 seconds, the call will be automatically ended with an ORIGINATOR_CANCELLED termination reason. This prevents situations where a user accepts a call but does not receive the invite due to network issues or other delays potentially causing infinite loading states in implementations. 

### Bug Fixing
- Fixed an issue where the Termination Cause was always 'USER_BUSY' regardless of current call state. Now, when terminating an active call, the state will be 'NORMAL_CLEARING' and when rejecting an invite, the Termination Cause will be 'USER_BUSY'.

## [2.0.0](https://pub.dev/packages/telnyx_webrtc/versions/2.0.0) (2025-06-13)

### Enhancement

- Enhanced call state reporting to include more detailed information about the call state changes.
- Enhanced error reporting to provide more context on errors encountered during call handling.
- Simplified push notification decline process. 

### Bug Fixing
- Fixed an issue where, on the Android and iOS clients, we weren't checking if the socket was open before sending messages. This could lead to 'StreamSink is closed' errors in niche edge cases. 

## [1.2.0](https://pub.dev/packages/telnyx_webrtc/versions/1.2.0) (2025-05-12)

### Enhancement

- Added WebRTC Call Quality Metrics for each initiated call (enabled via debug bool on invite or accept)
- Adjusted logging to be more clear for connection process and websocket messages


## [1.1.3](https://pub.dev/packages/telnyx_webrtc/versions/1.1.3) (2025-04-24)

### Bug Fixing

- Clear Push Metadata in more places to prevent issue where a call is attempting to be attached based on previously stored push metadata. You can also now manually clear the push metadata by calling `clearPushMetadata` method on the `TelnyxViewModel` class.
- Bump negotiation timeout to from 300ms to 500ms (per ice candidate)


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