import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/call_controls.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/header/control_header.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/login/login_controls.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    askForNotificationPermission();
  }

  Future<void> askForNotificationPermission() async {
    if (!kIsWeb) {
      await FlutterCallkitIncoming.requestNotificationPermission(
        'notification',
      );
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    }
  }

  void handleOptionClick(String value) {
    switch (value) {
      case 'Logout':
        Provider.of<TelnyxClientViewModel>(context, listen: false).disconnect();
        break;
      case 'Export Logs':
        Provider.of<TelnyxClientViewModel>(context, listen: false).exportLogs();
        break;
      case 'Disable Push Notifications':
        Provider.of<TelnyxClientViewModel>(context, listen: false).disablePushNotifications();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientState = context.select<TelnyxClientViewModel, CallStateStatus>(
      (txClient) => txClient.callState,
    );

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          // Only allow to log out or export logs when client is idle (not on a call or disconnected)
          if (clientState == CallStateStatus.idle)
            PopupMenuButton<String>(
              onSelected: handleOptionClick,
              itemBuilder: (BuildContext context) {
                return {'Logout', 'Export Logs', 'Disable Push Notifications'}.map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(choice),
                  );
                }).toList();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(spacingXXL),
          child: Column(
            children: [
              const ControlHeaders(),
              const SizedBox(height: spacingS),
              if (clientState == CallStateStatus.disconnected)
                const LoginControls()
              else
                const CallControls(),
            ],
          ),
        ),
      ),
    );
  }
}
