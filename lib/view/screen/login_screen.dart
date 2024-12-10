import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_flutter_webrtc/main.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final logger = Logger();
  bool _loggingIn = false;
  TextEditingController sipUserController = TextEditingController();
  TextEditingController sipPasswordController = TextEditingController();
  TextEditingController sipNameController = TextEditingController();
  TextEditingController sipNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _checkPermissions();
    }

    // Check if we have logged in before
    _checkCredentialsStored().then((value) {
      if (value) {
        _attemptLogin();
      } else {
        sipUserController.text = MOCK_USER;
        sipPasswordController.text = MOCK_PASSWORD;
      }
    });
  }

  void _checkPermissions() async {
    await [
      Permission.audio,
      Permission.microphone,
      Permission.bluetooth,
      Permission.bluetoothConnect,
    ].request();
  }

  Future<void> _attemptLogin() async {
    String? token;
    if (defaultTargetPlatform == TargetPlatform.android) {
      token = (await FirebaseMessaging.instance.getToken())!;
      logger.i('Android notification token :: $token');
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      logger.i('iOS notification token :: $token');
    }
    final credentialConfig = CredentialConfig(
      sipUser: sipUserController.text,
      sipPassword: sipPasswordController.text,
      sipCallerIDName: sipNameController.text,
      sipCallerIDNumber: sipNumberController.text,
      notificationToken: token,
      autoReconnect: true,
      debug: true,
      ringTonePath: 'assets/audio/incoming_call.mp3',
      ringbackPath: 'assets/audio/ringback_tone.mp3',
    );
    await _saveCredentialsForAutoLogin(credentialConfig);
    setState(() {
      _loggingIn = true;
      Provider.of<MainViewModel>(context, listen: false)
          .login(credentialConfig);
    });
  }

  Future<bool> _checkCredentialsStored() async {
    final prefs = await SharedPreferences.getInstance();
    final sipUser = prefs.getString('sipUser');
    final sipPassword = prefs.getString('sipPassword');
    final sipName = prefs.getString('sipName');
    final sipNumber = prefs.getString('sipNumber');
    if (sipUser != null &&
        sipPassword != null &&
        sipName != null &&
        sipNumber != null) {
      sipUserController.text = sipUser;
      sipPasswordController.text = sipPassword;
      sipNameController.text = sipName;
      sipNumberController.text = sipNumber;
      return true;
    }
    return false;
  }

  Future<void> _saveCredentialsForAutoLogin(
    CredentialConfig credentialConfig,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sipUser', credentialConfig.sipUser);
    await prefs.setString('sipPassword', credentialConfig.sipPassword);
    await prefs.setString('sipName', credentialConfig.sipCallerIDName);
    await prefs.setString('sipNumber', credentialConfig.sipCallerIDNumber);
    if (credentialConfig.notificationToken != null) {
      await prefs.setString(
        'notificationToken',
        credentialConfig.notificationToken!,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {}
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<MainViewModel>(context, listen: true).observeResponses();

    final bool registered =
        Provider.of<MainViewModel>(context, listen: true).registered;
    if (registered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/home');
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Telnyx Login'),
      ),
      body: _loggingIn
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Center(
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
                  ),
                ],
              ),
            ),
    );
  }
}
