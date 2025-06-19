import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/asset_paths.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';

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
              txClient.registered
                  ? 'Enter a destination (+E164 phone number or sip URI) to initiate your call.'
                  : 'Please confirm details below and click ‘Connect’ to make a call.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: spacingXL),
            Text('Socket', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: spacingS),
            SocketConnectivityStatus(isConnected: txClient.registered),
            const SizedBox(height: spacingXL),
            CallStateStatusWidget(callState: txClient.callState),
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
  final CallStateStatus callState;

  const CallStateStatusWidget({super.key, required this.callState});

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
            Text(callStateName),
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
