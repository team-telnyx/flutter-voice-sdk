import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/provider/telnyx_common_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/asset_paths.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_common/telnyx_common.dart';

/// Header component that uses telnyx_common provider for displaying connection status and controls.
class ControlHeaderTelnyxCommon extends StatefulWidget {
  final Function(String) onOptionSelected;
  
  const ControlHeaderTelnyxCommon({
    super.key,
    required this.onOptionSelected,
  });

  @override
  State<ControlHeaderTelnyxCommon> createState() => _ControlHeaderTelnyxCommonState();
}

class _ControlHeaderTelnyxCommonState extends State<ControlHeaderTelnyxCommon> {
  @override
  Widget build(BuildContext context) {
    return Consumer<TelnyxCommonProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // App bar with menu
            _buildAppBar(provider),
            
            // Logo
            Padding(
              padding: const EdgeInsets.symmetric(vertical: spacingS),
              child: Center(
                child: Image.asset(
                  logo_path,
                  width: logoWidth,
                  height: logoHeight,
                ),
              ),
            ),
            
            // Instructions text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingMedium),
              child: Text(
                provider.registered
                    ? 'Enter a destination (+E164 phone number or sip URI) to initiate your call.'
                    : 'Please confirm details below and click 'Connect' to make a call.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            
            const SizedBox(height: spacingXL),
            
            // Connection status section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Socket', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: spacingS),
                  SocketConnectivityStatusTelnyxCommon(connectionState: provider.connectionState),
                  const SizedBox(height: spacingXL),
                  
                  // Call state status
                  CallStateStatusWidgetTelnyxCommon(
                    callState: provider.callState,
                    activeCall: provider.activeCall,
                    terminationReason: provider.lastTerminationReason,
                  ),
                  const SizedBox(height: spacingXL),
                  
                  // Session ID
                  Text('Session ID', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: spacingS),
                  Text(
                    provider.sessionId.isNotEmpty ? provider.sessionId : 'Not connected',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppBar(TelnyxCommonProvider provider) {
    return AppBar(
      title: const Text('Telnyx WebRTC'),
      actions: [
        PopupMenuButton<String>(
          onSelected: widget.onOptionSelected,
          itemBuilder: (BuildContext context) {
            return [
              const PopupMenuItem<String>(
                value: 'Export Logs',
                child: Text('Export Logs'),
              ),
              if (provider.registered) ...[
                const PopupMenuItem<String>(
                  value: 'Disable Push Notifications',
                  child: Text('Disable Push Notifications'),
                ),
                const PopupMenuItem<String>(
                  value: 'Logout',
                  child: Text('Logout'),
                ),
              ] else ...[
                const PopupMenuItem<String>(
                  value: 'Enable Push Notifications',
                  child: Text('Enable Push Notifications'),
                ),
              ],
            ];
          },
        ),
      ],
    );
  }
}

/// Socket connectivity status widget for telnyx_common
class SocketConnectivityStatusTelnyxCommon extends StatelessWidget {
  final ConnectionState connectionState;
  
  const SocketConnectivityStatusTelnyxCommon({
    super.key,
    required this.connectionState,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    
    switch (connectionState) {
      case ConnectionState.connected:
        statusColor = Colors.green;
        statusText = 'Connected';
        break;
      case ConnectionState.connecting:
        statusColor = Colors.orange;
        statusText = 'Connecting...';
        break;
      case ConnectionState.disconnected:
        statusColor = Colors.red;
        statusText = 'Disconnected';
        break;
      case ConnectionState.error:
        statusColor = Colors.red;
        statusText = 'Error';
        break;
    }
    
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: spacingS),
        Text(
          statusText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Call state status widget for telnyx_common
class CallStateStatusWidgetTelnyxCommon extends StatelessWidget {
  final CallStateStatus callState;
  final Call? activeCall;
  final dynamic terminationReason; // CallTerminationReason from telnyx_webrtc
  
  const CallStateStatusWidgetTelnyxCommon({
    super.key,
    required this.callState,
    this.activeCall,
    this.terminationReason,
  });

  @override
  Widget build(BuildContext context) {
    String statusText = _getCallStateText();
    Color statusColor = _getCallStateColor();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Call State', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: spacingS),
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: spacingS),
            Expanded(
              child: Text(
                statusText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        
        // Show active call details if available
        if (activeCall != null) ...[
          const SizedBox(height: spacingS),
          Text(
            'Call ID: ${activeCall!.callId}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Destination: ${activeCall!.destination}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Direction: ${activeCall!.isIncoming ? 'incoming' : 'outgoing'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        
        // Show termination reason if available
        if (terminationReason != null) ...[
          const SizedBox(height: spacingS),
          Text(
            'Last termination: ${terminationReason.toString()}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.orange,
            ),
          ),
        ],
      ],
    );
  }
  
  String _getCallStateText() {
    switch (callState) {
      case CallStateStatus.disconnected:
        return 'Disconnected';
      case CallStateStatus.idle:
        return 'Idle';
      case CallStateStatus.ringing:
        return 'Ringing';
      case CallStateStatus.ongoingInvitation:
        return 'Incoming Call';
      case CallStateStatus.connectingToCall:
        return 'Connecting to Call';
      case CallStateStatus.ongoingCall:
        return 'Call Active';
    }
  }
  
  Color _getCallStateColor() {
    switch (callState) {
      case CallStateStatus.disconnected:
        return Colors.red;
      case CallStateStatus.idle:
        return Colors.grey;
      case CallStateStatus.ringing:
      case CallStateStatus.ongoingInvitation:
      case CallStateStatus.connectingToCall:
        return Colors.orange;
      case CallStateStatus.ongoingCall:
        return Colors.green;
    }
  }
}