import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/config/telnyx_config.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final logger = Logger();
  TextEditingController destinationController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  void _callDestination() {
    //Provider.of<MainViewModel>(context, listen: false).login(credentialConfig);
    logger.i('Calling!');
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
                controller: destinationController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Destination',
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
                  _callDestination();
                },
                child: const Text('Call'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
