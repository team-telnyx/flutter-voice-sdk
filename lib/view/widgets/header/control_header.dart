import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
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
          children: <Widget>[
            SvgPicture.asset('assets/telnyx_logo.svg'),
            Text(
              txClient.registered
                  ? 'Enter a destination (+E164 phone number or sip URI) to initiate your call.'
                  : 'Please confirm details below and click ‘Connect’ to make a call.',
            ),
            const SizedBox(height: 20),
            const Text('Socket'),
            const SizedBox(height: 10),
            SocketConnectivityStatus(isConnected: txClient.registered),
            const SizedBox(height: 20),
            const Text('Session ID'),
            const SizedBox(height: 10),
            const Text('-'),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isConnected ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 10),
        Text(isConnected ? 'Client-ready' : 'Disconnected'),
      ],
    );
  }
}
