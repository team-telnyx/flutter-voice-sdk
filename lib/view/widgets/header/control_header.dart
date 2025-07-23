import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_common/telnyx_common.dart' as telnyx;
import 'package:telnyx_flutter_webrtc/utils/asset_paths.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_webrtc/model/call_termination_reason.dart';

class ControlHeaders extends StatefulWidget {
  const ControlHeaders({super.key});

  @override
  State<ControlHeaders> createState() => _ControlHeadersState();
}

class _ControlHeadersState extends State<ControlHeaders> {
  @override
  Widget build(BuildContext context) {
    return Consumer<TelnyxClientViewModel>(
      builder: (context, txClient, child) {
        final isConnected = txClient.connectionState is telnyx.Connected;
        final callState = txClient.activeCall?.currentState;
        final isConnectingToCall = txClient.isConnectingToCall;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
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
            Text(
              isConnected && txClient.activeCall == null
                  ? 'Enter a destination (+E164 phone number or sip URI) to initiate your call.'
                  : 'Please confirm details below and click ‘Connect’ to make a call.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: spacingXL),
            Text('Socket', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: spacingS),
            SocketConnectivityStatus(isConnected: isConnected),
            const SizedBox(height: spacingXL),
            CallStateStatusWidget(
              callState: callState,
              isConnecting: isConnectingToCall,
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
  final bool isConnected;

  const SocketConnectivityStatus({super.key, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: spacingS,
          height: spacingS,
          decoration: BoxDecoration(
            color: isConnected ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: spacingS),
        Text(isConnected ? 'Client-ready' : 'Disconnected'),
      ],
    );
  }
}

class CallStateStatusWidget extends StatelessWidget {
  final telnyx.CallState? callState;
  final bool isConnecting;
  final CallTerminationReason? terminationReason;

  const CallStateStatusWidget({
    super.key,
    this.callState,
    this.isConnecting = false,
    this.terminationReason,
  });

  @override
  Widget build(BuildContext context) {
    final stateForDisplay = isConnecting ? null : callState;
    final callStateColor = _getCallStateColor(stateForDisplay, isConnecting);
    final callStateName = _getCallStateName(stateForDisplay, isConnecting);

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
            Expanded(
                child: Text(
              callStateName,
              overflow: TextOverflow.ellipsis,
            )),
          ],
        ),
      ],
    );
  }

  Color _getCallStateColor(telnyx.CallState? state, bool isConnecting) {
    if (isConnecting) return const Color(0xFF3434EF); // Connecting - blue

    switch (state) {
      case telnyx.CallState.active:
        return Colors.green;
      case telnyx.CallState.held:
        return Colors.orange;
      case telnyx.CallState.ringing:
      case telnyx.CallState.initiating:
      case telnyx.CallState.reconnecting:
        return const Color(0xFF3434EF); // Ringing/connecting states - blue
      case telnyx.CallState.ended:
      case telnyx.CallState.error:
      default:
        return const Color(0xFF93928D); // Idle/ended states - gray
    }
  }

  String _getCallStateName(telnyx.CallState? state, bool isConnecting) {
    if (isConnecting) return 'Connecting...';

    switch (state) {
      case null:
        if (terminationReason != null) {
          return 'Done - ${terminationReason?.cause.toString() ?? 'NORMAL_CLEARING'}';
        }
        return 'Idle';
      case telnyx.CallState.initiating:
        return 'Initiating';
      case telnyx.CallState.ringing:
        return 'Ringing';
      case telnyx.CallState.active:
        return 'Active';
      case telnyx.CallState.held:
        return 'Held';
      case telnyx.CallState.reconnecting:
        return 'Reconnecting';
      case telnyx.CallState.ended:
        return 'Ended';
      case telnyx.CallState.error:
        return 'Error';
    }
  }
}
