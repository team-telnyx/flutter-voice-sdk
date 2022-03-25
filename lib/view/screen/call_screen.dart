import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final logger = Logger();
  TextEditingController sipUserController = TextEditingController();
  TextEditingController sipPasswordController = TextEditingController();
  TextEditingController sipNameController = TextEditingController();
  TextEditingController sipNumberController = TextEditingController();

  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<MainViewModel>(context, listen: true).observeResponses();
    Provider.of<MainViewModel>(context, listen: true).connect();
    bool registered =
        Provider.of<MainViewModel>(context, listen: true).registered;
    if (registered) {
      WidgetsBinding.instance?.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/home');
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child:  Column(
          children: [
            const Text("Ongoing call..."),
            Row(
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    primary: Colors.red[400],
                  ),
                  onPressed: () {
                    print("Decline Call");
                  },
                  child: const Text('End Call'),
                ),
              ],
            )
          ],
        )
      ),
    );
  }
}
