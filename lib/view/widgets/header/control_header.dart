import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/asset_paths.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_webrtc/model/call_termination_reason.dart';
import 'package:telnyx_webrtc/model/connection_status.dart';
import 'package:telnyx_webrtc/model/socket_connection_metrics.dart';
import '../connection_details_bottom_sheet.dart';
import '../environment_bottom_sheet.dart';

class ControlHeaders extends StatefulWidget {
  const ControlHeaders({super.key});

  @override
  State<ControlHeaders> createState() => _ControlHeadersState();
}

class _ControlHeadersState extends State<ControlHeaders> {
  void _showConnectionDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ConnectionDetailsBottomSheet(),
    );
  }

  void _showEnvironmentBottomSheet(BuildContext context) {
    final connectionStatus =
        context.read<TelnyxClientViewModel>().connectionStatus;
    // Only show environment switcher when disconnected
    if (connectionStatus == ConnectionStatus.disconnected) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const EnvironmentBottomSheet(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TelnyxClientViewModel>(
      builder: (context, txClient, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: spacingS),
              child: Center(
                child: GestureDetector(
                  onLongPress: () => _showEnvironmentBottomSheet(context),
                  child: Image.asset(
                    logo_path,
                    width: logoWidth,
                    height: logoHeight,
                  ),
                ),
              ),
            ),
            Text(
              txClient.registered
                  ? 'Enter a destination (+E164 phone number or sip URI) to initiate your call.'
                  : 'Please confirm details below and click ‘Connect’ to make a call.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: spacingXL),
            Text('Socket', style: Theme.of(context).textTheme.labelMedium),
            SocketConnectivityStatus(
              connectionStatus: txClient.connectionStatus,
              autoReconnectEnabled: txClient.isAutoReconnectEnabled,
              retryCount: txClient.connectionRetryCount,
              connectionMetrics: txClient.connectionMetrics,
              onShowDetails: () => _showConnectionDetails(context),
            ),
            const SizedBox(height: spacingXL),
            CallStateStatusWidget(
              callState: txClient.callState,
              terminationReason: txClient.lastTerminationReason,
            ),
            const SizedBox(height: spacingXL),
            Text('Session ID', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: spacingS),
            Text(
              context.select<TelnyxClientViewModel, String>(
                (txClient) => txClient.sessionId,
              ),
            ),
            const SizedBox(height: spacingXL),
          ],
        );
      },
    );
  }
}

class SocketConnectivityStatus extends StatelessWidget {
  final ConnectionStatus connectionStatus;
  final bool autoReconnectEnabled;
  final int retryCount;
  final SocketConnectionMetrics? connectionMetrics;
  final VoidCallback? onShowDetails;

  const SocketConnectivityStatus({
    super.key,
    required this.connectionStatus,
    required this.autoReconnectEnabled,
    required this.retryCount,
    this.connectionMetrics,
    this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the connection state and color based on ConnectionStatus enum
    String connectionStatusText;
    Color statusColor;

    switch (connectionStatus) {
      case ConnectionStatus.disconnected:
        connectionStatusText = 'Disconnected';
        statusColor = Colors.red;
        break;
      case ConnectionStatus.connected:
        connectionStatusText = 'Connected (Registering...)';
        statusColor = Colors.orange;
        break;
      case ConnectionStatus.reconnecting:
        connectionStatusText = retryCount > 0
            ? 'Reconnecting... (${retryCount})'
            : 'Reconnecting...';
        statusColor = Colors.yellow;
        break;
      case ConnectionStatus.clientReady:
        connectionStatusText = 'Client-ready';
        statusColor = Colors.green;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: spacingS,
              height: spacingS,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: spacingS),
            Text(connectionStatusText),
            if (connectionMetrics != null &&
                connectionStatus == ConnectionStatus.clientReady)
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                onPressed: onShowDetails,
                tooltip: 'View connection details',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}

class CallStateStatusWidget extends StatelessWidget {
  final CallStateStatus callState;
  final CallTerminationReason? terminationReason;

  const CallStateStatusWidget({
    super.key,
    required this.callState,
    this.terminationReason,
  });

  @override
  Widget build(BuildContext context) {
    final callStateColor = _getCallStateColor(callState);
    final callStateName = _getCallStateName(callState);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Call State', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: spacingS),
        Row(
          children: <Widget>[
            Container(
              width: spacingS,
              height: spacingS,
              decoration: BoxDecoration(
                color: callStateColor,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: spacingS),
            Expanded(child: Text(callStateName)),
          ],
        ),
      ],
    );
  }

  Color _getCallStateColor(CallStateStatus state) {
    switch (state) {
      case CallStateStatus.ongoingCall:
        return Colors.green; // Active call - green
      case CallStateStatus.ringing:
      case CallStateStatus.ongoingInvitation:
        return const Color(0xFF3434EF); // Ringing - blue
      case CallStateStatus.connectingToCall:
        return const Color(0xFF3434EF); // Connecting - blue
      case CallStateStatus.disconnected:
      case CallStateStatus.idle:
        return const Color(0xFF93928D); // Done/Idle - gray
    }
  }

  String _getCallStateName(CallStateStatus state) {
    switch (state) {
      case CallStateStatus.disconnected:
        return 'Disconnected';
      case CallStateStatus.idle:
        // Show termination reason if available and recent
        if (terminationReason != null) {
          return 'Done - ${terminationReason?.cause.toString() ?? 'NORMAL_CLEARING'}';
        }
        return 'Idle';
      case CallStateStatus.ringing:
        return 'Ringing';
      case CallStateStatus.ongoingInvitation:
        return 'Incoming';
      case CallStateStatus.connectingToCall:
        return 'Connecting';
      case CallStateStatus.ongoingCall:
        return 'Active';
    }
  }
}
