import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_flutter_webrtc/view/screen/call_screen.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/invitation_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final logger = Logger();
  TextEditingController destinationController = TextEditingController();

  bool invitation = false;
  bool ongoingCall = false;

  @override
  void initState() {
    super.initState();
  }

  void _observeResponses() {
    Provider.of<MainViewModel>(context, listen: true).observeResponses();
    invitation =
        Provider.of<MainViewModel>(context, listen: true).ongoingInvitation;
    ongoingCall = Provider.of<MainViewModel>(context, listen: true).ongoingCall;
  }

  void _callDestination() {
    Provider.of<MainViewModel>(context, listen: false)
        .call(destinationController.text);
    logger.i('Calling!');
  }

  @override
  Widget build(BuildContext context) {
    _observeResponses();
    if (invitation) {
      return InvitationWidget(
          title: 'Home',
          invitation: Provider.of<MainViewModel>(context, listen: false)
              .incomingInvitation);
    } else if (ongoingCall) {
      return CallScreen(
          title: "Ongoing Call",
          call: Provider.of<MainViewModel>(context, listen: false).currentCall);
    } else {
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
}
