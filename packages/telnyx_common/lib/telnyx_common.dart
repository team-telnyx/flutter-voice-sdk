/// A high-level, state-agnostic, drop-in module for the Telnyx Flutter SDK.
///
/// This library provides a simplified interface for integrating Telnyx WebRTC
/// capabilities into Flutter applications. It handles session management,
/// call state transitions, push notification processing, and native call UI
/// integration.
library telnyx_common;

export 'src/telnyx_voip_client.dart';
export 'src/models/call.dart';
export 'src/models/connection_state.dart';
export 'src/models/call_state.dart';
export 'utils/iterable_extensions.dart';

// Re-export telnyx_config classes directly
export 'package:telnyx_webrtc/config/telnyx_config.dart';
export 'package:telnyx_webrtc/utils/logging/log_level.dart';
export 'package:telnyx_webrtc/utils/logging/custom_logger.dart';
export 'package:telnyx_webrtc/model/region.dart';