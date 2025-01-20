import 'package:flutter/material.dart';

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
      children: <Widget>[
        const Text('Token Login'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Switch(
              value: isTokenLogin,
              onChanged: (value) {
                setState(() {
                  isTokenLogin = value;
                });
              },
            ),
            Text(isTokenLogin ? 'On' : 'Off'),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Profile'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Text('User'),
            ElevatedButton(
              onPressed: () {
                // Open Bottom Sheet
              },
              child: const Text('Switch Profile'),
            ),
          ],
        ),
        Spacer(),
        ElevatedButton(
          onPressed: () {
            // Logout
          },
          child: const Text('Connect'),
        ),
      ],
    );
  }
}
