import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/config/telnyx_config.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

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
  final logger = Logger();
  final MainViewModel _mainViewModel = MainViewModel();
  TextEditingController sipUserController = TextEditingController();
  TextEditingController sipPasswordController = TextEditingController();
  TextEditingController sipNameController = TextEditingController();
  TextEditingController sipNumberController = TextEditingController();

  @override
  void initState() {
    _mainViewModel.observeResponses();
    _mainViewModel.connect();
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
      _mainViewModel.login(credentialConfig);
    });
  }

  @override
  Widget build(BuildContext context) {
    bool registered = Provider.of<MainViewModel>(context) as bool;
    if (registered) {
      logger.i('Navigate to home screen!');
    }

    //ToDo Move login page to it's on screen.

    return
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: MainViewModel()),
        ],
        child:  Scaffold(
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
        ),
      );
  }
}
