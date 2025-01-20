import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';

class LoginControls extends StatefulWidget {
  const LoginControls({super.key});

  @override
  State<LoginControls> createState() => _LoginControlsState();
}

class _LoginControlsState extends State<LoginControls> {
  bool isTokenLogin = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Token Login', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: spacingS),
        Row(
          children: <Widget>[
            Switch(
              value: isTokenLogin,
              onChanged: (value) {
                setState(() {
                  isTokenLogin = value;
                });
              },
            ),
            SizedBox(width: spacingS),
            Text(isTokenLogin ? 'On' : 'Off'),
          ],
        ),
        const SizedBox(height: spacingXL),
        Text('Profile', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: spacingS),
        Row(
          children: <Widget>[
            Text('User'),
            SizedBox(width: spacingS),
            TextButton(
              onPressed: () {},
              child: const Text('Switch Profile'),
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Provider.of<TelnyxClientViewModel>(context, listen: false).login(
                CredentialConfig(
                  sipUser: 'placeholder',
                  sipPassword: 'placeholder',
                  sipCallerIDName: 'placeholder',
                  sipCallerIDNumber: 'placeholder',
                  debug: false,
                ),
              );
            },
            child: const Text('Connect'),
          ),
        ),
      ],
    );
  }
}
