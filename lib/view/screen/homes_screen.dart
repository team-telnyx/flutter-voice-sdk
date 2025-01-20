import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_svg/svg.dart';
import 'package:permission_handler/permission_handler.dart';

class HomesScreen extends StatefulWidget {
  const HomesScreen({super.key});

  @override
  State<HomesScreen> createState() => _HomesScreenState();
}

class _HomesScreenState extends State<HomesScreen> {

  @override
  void initState() {
    super.initState();
    askForNotificationPermission();
  }

  Future<void> askForNotificationPermission() async {
    await FlutterCallkitIncoming.requestNotificationPermission('notification');
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const ControlHeaders(isConnected: true),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class LoginControls extends StatefulWidget {
  const LoginControls({super.key});

  @override
  State<LoginControls> createState() => _LoginControlsState();
}

class _LoginControlsState extends State<LoginControls> {
  bool isTokenLogin = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Text('Token Login'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Switch(
              value: isTokenLogin,
              onChanged: (value) {
                setState(() {
                  isTokenLogin = value;
                });
              },
            ),
            Text(isTokenLogin ? 'On' : 'Off'),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Profile'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Text('User'),
            ElevatedButton(
              onPressed: () {
                // Open Bottom Sheet
              },
              child: const Text('Switch Profile'),
            ),
          ],
        ),
        Spacer(),
        ElevatedButton(
          onPressed: () {
            // Logout
          },
          child: const Text('Connect'),
        ),
      ],
    );
  }
}

class ControlHeaders extends StatefulWidget {
  final bool isConnected;

  const ControlHeaders({super.key, required this.isConnected});

  @override
  State<ControlHeaders> createState() => _ControlHeadersState();
}

class _ControlHeadersState extends State<ControlHeaders> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SvgPicture.asset('assets/telnyx_logo.svg'),
        Text(
          widget.isConnected
              ? 'Enter a destination (+E164 phone number or sip URI) to initiate your call.'
              : 'Please confirm details below and click ‘Connect’ to make a call.',
        ),
        const SizedBox(height: 20),
        const Text('Socket'),
        const SizedBox(height: 10),
        SocketConnectivityStatus(isConnected: widget.isConnected),
        const SizedBox(height: 20),
        const Text('Session ID'),
        const SizedBox(height: 10),
        const Text('-'),
      ],
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
