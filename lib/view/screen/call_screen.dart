import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/dialpad_widget.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child:  Column(
          children: [
            DialPad(
                outputMask: "",
                backspaceButtonIconColor: Colors.red,
                makeCall: (number){
                  print(number);
                }
            )
          ],
        )
      ),
    );
  }
}
