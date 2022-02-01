import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/telnyx_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TelnyxClient telnyxClient = TelnyxClient();
  TextEditingController sipUserController = TextEditingController();
  TextEditingController sipPasswordController = TextEditingController();
  TextEditingController sipNameController = TextEditingController();
  TextEditingController sipNumberController = TextEditingController();

  @override
  void initState() {
    telnyxClient.connect("wss://rtc.telnyx.com:443");
    super.initState();
  }

  void _attemptLogin() {
    setState(() {
      var credentialConfig = CredentialConfig(
          sipUserController.text,
          sipPasswordController.text,
          sipNameController.text,
          sipNumberController.text,
          null);
      telnyxClient.credentialLogin(credentialConfig);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  primary: Colors.blue,
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
}
