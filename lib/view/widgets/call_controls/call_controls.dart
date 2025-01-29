import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/buttons/call_buttons.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/call_invitation.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/ongoing_call_controls.dart';

class CallControls extends StatefulWidget {
  const CallControls({super.key});

  @override
  State<CallControls> createState() => _CallControlsState();
}

class _CallControlsState extends State<CallControls> {
  final _destinationController = TextEditingController();

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientState = context.select<TelnyxClientViewModel, CallStateStatus>(
      (txClient) => txClient.callState,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Destination', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: spacingXS),
        Padding(
          padding: const EdgeInsets.all(spacingXS),
          child: TextFormField(
            readOnly: clientState != CallStateStatus.idle,
            enabled: clientState == CallStateStatus.idle,
            controller: _destinationController,
            decoration: InputDecoration(
              hintStyle: Theme.of(context).textTheme.labelSmall,
              hintText: '+E164 phone number or SIP URI',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(spacingS),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: active_text_field_color),
                borderRadius: BorderRadius.circular(spacingS),
              ),
            ),
          ),
        ),
        const SizedBox(height: spacingXXXXL),
        if (clientState == CallStateStatus.idle)
          Center(
            child: CallButton(
              onPressed: () {
                final destination = _destinationController.text;
                if (destination.isNotEmpty) {
                  context.read<TelnyxClientViewModel>().call(destination);
                }
              },
            ),
          )
        else if (clientState == CallStateStatus.ringing)
          Center(
            child: DeclineButton(
              onPressed: () {
                context.read<TelnyxClientViewModel>().endCall();
              },
            ),
          )
        else if (clientState == CallStateStatus.ongoingInvitation)
          Center(
            child: CallInvitation(
              onAccept: () {
                context.read<TelnyxClientViewModel>().accept();
              },
              onDecline: () {
                context.read<TelnyxClientViewModel>().endCall();
              },
            ),
          )
        else if (clientState == CallStateStatus.connectingToCall)
          Center(
            child: CircularProgressIndicator(),
          )
        else if (clientState == CallStateStatus.ongoingCall)
          Center(
            child: OnGoingCallControls(),
          ),
      ],
    );
  }
}
