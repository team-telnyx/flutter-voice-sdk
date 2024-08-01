// ignore: avoid_web_libraries_in_flutter
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:telnyx_flutter_webrtc/main.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final logger = Logger();
  TextEditingController sipUserController = TextEditingController();
  TextEditingController sipPasswordController = TextEditingController();
  TextEditingController sipNameController = TextEditingController();
  TextEditingController sipNumberController = TextEditingController();

  @override
  initState() {
    if (!kIsWeb) {
      _checkPermissions();
    }
    logger.i("Version ${Platform.operatingSystemVersion}");

    sipUserController.text = MOCK_USER;
    sipPasswordController.text = MOCK_PASSWORD;

    super.initState();
  }

  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.audio,
      Permission.microphone,
      Permission.bluetooth,
      Permission.bluetoothConnect
    ].request();
    print(statuses[Permission.microphone]);
    print(statuses[Permission.bluetooth]);
  }

  Future<void> _attemptLogin() async {
    String? token;
    if (defaultTargetPlatform == TargetPlatform.android) {
      token = (await FirebaseMessaging.instance.getToken())!;
      logger.i("Android notification token :: $token");
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      logger.i("iOS notification token :: $token");
    }
    setState(() {
      var credentialConfig = CredentialConfig(
          sipUserController.text,
          sipPasswordController.text,
          sipNameController.text,
          sipNumberController.text,
          token,
          true,
          "assets/audio/incoming_call.mp3",
          "assets/audio/ringback_tone.mp3");

      var tokenConfig = TokenConfig(
          "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJ0ZWxueXhfdGVsZXBob255IiwiZXhwIjoxNzA5NjM0Mzk4LCJpYXQiOjE3MDk1NDc5OTgsImlzcyI6InRlbG55eF90ZWxlcGhvbnkiLCJqdGkiOiIzOWY3ZDY2ZS0xY2JiLTQ2Y2QtOGM4ZS03NDJlOWZlYTUwNDAiLCJuYmYiOjE3MDk1NDc5OTcsInN1YiI6Ijg2YmEyZjA3LWU4NmEtNGU3NS05MTg2LTAwOTYxYWMzNDc0ZSIsInRlbF90b2tlbiI6Ik5iVldCTFFySDRoWk9TS2FGa0ZfMlctcndWcklJbExJcnltZkRFY0RETThydFk0ZUp6TkhmTVlaeWJyNVk2b0tTd2Exa0toZzZrREdDNHd4dUVSTDlodUdqOV9nRk5oVjZwVzRSWFB0dGFWMF9fNXhoVVRHb3F5czdmX0FsVUotZjZzNEktQXNMcm9vc3djNW13SEE3VmdHIiwidHlwIjoiYWNjZXNzIn0.8Y_MdGid2iZg0ERLJxQEbR2R5JRkg6kS_g0P4v5qFEvLWw4MIfEoUXMxyvSEvPd4t3ySS7xeB2_NFCB02kEDVg",
          sipNameController.text,
          sipNumberController.text,
          token,
          true,
          "",
          "");
      Provider.of<MainViewModel>(context, listen: false)
          .login(credentialConfig);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {}
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<MainViewModel>(context, listen: true).observeResponses();

    bool registered =
        Provider.of<MainViewModel>(context, listen: true).registered;
    if (registered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/home');
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                controller: sipUserController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'SIP Username',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                controller: sipPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'SIP Password',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                controller: sipNameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Caller ID Name',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                controller: sipNumberController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Caller ID Number',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
                onPressed: () {
                  _attemptLogin();
                },
                child: const Text('Login'),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showToast(BuildContext context, String text) {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: Text('$text'),
        action: SnackBarAction(
            label: 'OKAY', onPressed: scaffold.hideCurrentSnackBar),
      ),
    );
  }
}
