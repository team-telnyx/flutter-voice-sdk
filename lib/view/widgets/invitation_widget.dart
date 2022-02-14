import 'package:flutter/material.dart';

class InvitationWidget extends StatelessWidget {
  const InvitationWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Text("Incoming Call"),
      Row(children: [
        TextButton(
          style: TextButton.styleFrom(
            primary: Colors.green[500],
          ),
          onPressed: () {
            print("Accept Call");
          },
          child: const Text('Accept'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            primary: Colors.red[400],
          ),
          onPressed: () {
            print("Decline Call");
          },
          child: const Text('Decline'),
        ),
      ])
    ]);
  }
}
