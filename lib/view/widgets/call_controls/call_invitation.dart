import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/buttons/call_buttons.dart';

class CallInvitation extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const CallInvitation({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        CallButton(
          onPressed: onAccept,
        ),
        SizedBox(width: spacingM),
        DeclineButton(
          onPressed: onDecline,
        ),
      ],
    );
  }
}
