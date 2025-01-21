import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_webrtc/telnyx_config.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/login/bottom_sheet/profile_switcher_bottom_sheet.dart';

class LoginControls extends StatefulWidget {
  const LoginControls({Key? key}) : super(key: key);

  @override
  _LoginControlsState createState() => _LoginControlsState();
}

class _LoginControlsState extends State<LoginControls> {
  String selectedProfileName = 'User';

  void _showProfileSwitcher() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const ProfileSwitcherBottomSheet(),
      ),
    );

    if (result != null) {
      setState(() {
        selectedProfileName = result['type'] == 'token'
            ? 'Token Profile'
            : result['username'];
      });

      if (result['type'] == 'token') {
        Provider.of<MainViewModel>(context, listen: false).login(
          TokenConfig(
            token: result['token'],
            debug: false,
          ),
        );
      } else {
        Provider.of<MainViewModel>(context, listen: false).login(
          CredentialConfig(
            sipUser: result['username'],
            sipPassword: result['password'],
            sipCallerIDName: result['username'],
            sipCallerIDNumber: result['username'],
            debug: false,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: <Widget>[
            Text(selectedProfileName),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _showProfileSwitcher,
              child: const Text('Switch Profile'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Connect button will be enabled when a profile is selected
              // The login is handled in the profile switcher
            },
            child: const Text('Connect'),
          ),
        ),
      ],
    );
  }
}