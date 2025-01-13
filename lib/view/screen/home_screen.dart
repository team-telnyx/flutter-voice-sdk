import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_flutter_webrtc/view/screen/call_screen.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/invitation_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
    askForNotificationPermission();
  }

  Future<void> askForNotificationPermission() async {
    await FlutterCallkitIncoming.requestNotificationPermission('notification');
    final status = await Permission.notification.status;
    if (status.isDenied) {
      // We haven't asked for permission yet or the permission has been denied before, but not permanently
      await Permission.notification.request();
    }
    // You can also directly ask permission about its status.
    if (await Permission.location.isRestricted) {
      // The OS restricts access, for example, because of parental controls.
    }
  }

  void _observeResponses() {
    invitation = Provider.of<MainViewModel>(context, listen: true).callState ==
        CallStateStatus.ongoingInvitation;
    ongoingCall = Provider.of<MainViewModel>(context, listen: true).callState ==
        CallStateStatus.ongoingCall;
  }

  void _callDestination() {
    Provider.of<MainViewModel>(context, listen: false)
        .call(destinationController.text);
    logger.i('Calling!');
  }

  void _endCall() {
    Provider.of<MainViewModel>(context, listen: false).endCall();
    logger.i('Calling!');
  }

  void handleOptionClick(String value) {
    switch (value) {
      case 'Logout':
        Provider.of<MainViewModel>(context, listen: false).disconnect();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed('/');
        });
        logger.i('Disconnecting!');
        break;
      case 'Export Logs':
        Provider.of<MainViewModel>(context, listen: false).exportLogs();
        logger.i('Exporting logs!');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    _observeResponses();
    if (invitation) {
      return InvitationWidget(
        title: 'Home',
        invitation: Provider.of<MainViewModel>(context, listen: false)
            .incomingInvitation,
      );
    } else if (ongoingCall) {
      return CallScreen(
        call: Provider.of<MainViewModel>(context, listen: false).currentCall,
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: Text('Home'),
          actions: <Widget>[
            PopupMenuButton<String>(
              onSelected: handleOptionClick,
              itemBuilder: (BuildContext context) {
                return {'Logout', 'Export Logs'}.map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(choice),
                  );
                }).toList();
              },
            ),
          ],
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
                    labelText: 'Enter Destination Number',
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
                    _callDestination();
                  },
                  child: const Text('Call'),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
