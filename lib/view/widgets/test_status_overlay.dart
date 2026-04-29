import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_webrtc/model/connection_status.dart';

/// Test status overlay for integration tests.
///
/// Displays SDK connection and call state with predictable Keys,
/// allowing Patrol tests to poll for actual state instead of
/// using arbitrary timeouts.
///
/// Only visible when TEST_MODE environment variable is set.
class TestStatusOverlay extends StatelessWidget {
  final CallStateStatus callState;
  final ConnectionStatus connectionStatus;

  const TestStatusOverlay({
    super.key,
    required this.callState,
    required this.connectionStatus,
  });

  /// Check if test mode is enabled via environment variable
  static const bool isTestMode = bool.fromEnvironment(
    'TEST_MODE',
    defaultValue: false,
  );

  @override
  Widget build(BuildContext context) {
    // Only show in test mode or debug builds
    if (!isTestMode && !kDebugMode) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 100,
      right: 8,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                connectionStatus.name,
                key: const Key('connection_status'),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                callState.name,
                key: const Key('call_status'),
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
