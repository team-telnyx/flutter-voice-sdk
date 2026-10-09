/// Re-export of [TelnyxError] from the errors module.
///
/// This ensures a single source of truth for the [TelnyxError] class
/// while maintaining backward compatibility with imports that use
/// `package:telnyx_webrtc/model/telnyx_error.dart`.
library;

export 'package:telnyx_webrtc/model/errors/telnyx_error.dart';
