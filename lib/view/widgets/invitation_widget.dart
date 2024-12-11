import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';

class InvitationWidget extends StatelessWidget {
  const InvitationWidget({super.key, required this.title, this.invitation});
  final String title;
  final IncomingInviteParams? invitation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(invitation?.callerIdName ?? 'Unknown Caller'),
            Text(invitation?.callerIdNumber ?? 'Unknown Number'),
            const Text('Incoming Call'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[400],
                  ),
                  onPressed: () {
                    Provider.of<MainViewModel>(context, listen: false)
                        .endCall();
                    print('Decline Call');
                  },
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
