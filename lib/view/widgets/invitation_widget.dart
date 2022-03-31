import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:provider/provider.dart';

class InvitationWidget extends StatelessWidget {
  const InvitationWidget({Key? key, required this.title}) : super(key: key);
  final String title;

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
                const Text("Incoming Call"),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      primary: Colors.green[500],
                    ),
                    onPressed: () {
                      print("Accept Call");
                      Provider.of<MainViewModel>(context, listen: false)
                          .accept();
                    },
                    child: const Text('Accept'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      primary: Colors.red[400],
                    ),
                    onPressed: () {
                      Provider.of<MainViewModel>(context, listen: false)
                          .endCall();
                      print("Decline Call");
                    },
                    child: const Text('Decline'),
                  ),
                ])
              ]),
        ));
  }
}
