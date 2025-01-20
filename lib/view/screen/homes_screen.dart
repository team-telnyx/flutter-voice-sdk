import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/screen/call_screen.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/header/control_header.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/invitation_widget.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/login/login_controls.dart';

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
    final clientState = context.select<TelnyxClientViewModel, CallStateStatus>(
      (txClient) => txClient.callState,
    );

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(spacingL),
          child: Column(
            children: [
              const ControlHeaders(),
              const SizedBox(height: spacingS),
              if (clientState == CallStateStatus.disconnected)
                const LoginControls(),
              if (clientState == CallStateStatus.idle) Text('Destination'),
              if (clientState == CallStateStatus.ringing) const Text('Ringing'),
              if (clientState == CallStateStatus.ongoingInvitation)
                const InvitationWidget(
                  title: '',
                ),
              if (clientState == CallStateStatus.ongoingCall)
                const CallScreen(),
            ],
          ),
        ),
      ),
    );
  }
}
