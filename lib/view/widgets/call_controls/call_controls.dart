import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/asset_paths.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';

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
                // ToDo add call functionality
              },
            ),
          )
        else if (clientState == CallStateStatus.ongoingInvitation)
          Center(
            child: CallInvitation(
              onAccept: () {
                // ToDo add accept functionality
              },
              onDecline: () {
                // ToDo add decline functionality
              },
            ),
          )
        else if (clientState == CallStateStatus.ongoingCall)
          Center(
            child: CallButton(
              onPressed: () {
                // ToDo add hangup functionality
              },
            ),
          ),
      ],
    );
  }
}

class OnGoingCallControls extends StatelessWidget {
  final VoidCallback onHangup;

  const OnGoingCallControls({super.key, required this.onHangup});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            CallControlButton(
              enabledIcon: Icons.mic,
              disabledIcon: Icons.mic_off,
              isDisabled: false,
              /* ToDo get this from provider */
              onEnabled: () {
                // ToDo add mute functionality
              },
              onDisabled: () {
                // ToDo add unmute functionality
              },
            ),
            DeclineButton(
              onPressed: () {
                // ToDo add hangup functionality
              },
            ),
            CallControlButton(
              enabledIcon: Icons.volume_up,
              disabledIcon: Icons.volume_off,
              isDisabled: false,
              /* ToDo get this from provider */
              onEnabled: () {
                // ToDo add speaker functionality
              },
              onDisabled: () {
                // ToDo add speaker functionality
              },
            ),
          ],
        ),
        Row(
          children: [
            CallControlButton(
              enabledIcon: Icons.play_arrow,
              disabledIcon: Icons.pause,
              isDisabled: false,
              /* ToDo get this from provider */
              onEnabled: () {
                // ToDo add hold functionality
              },
              onDisabled: () {
                // ToDo add unhold functionality
              },
            ),
            SizedBox(width: iconSize),
            CallControlButton(
              enabledIcon: Icons.dialpad,
              disabledIcon: Icons.dialpad,
              isDisabled: false,
              onEnabled: () {
                // ToDo add dialpad functionality
              },
              onDisabled: () {
                // ToDo add dialpad functionality
              },
            ),
          ],
        )
      ],
    );
  }
}

class CallControlButton extends StatefulWidget {
  final IconData enabledIcon;
  final IconData disabledIcon;
  final bool isDisabled;
  final VoidCallback onEnabled;
  final VoidCallback onDisabled;

  const CallControlButton({
    super.key,
    required this.enabledIcon,
    required this.disabledIcon,
    required this.isDisabled,
    required this.onEnabled,
    required this.onDisabled,
  });

  @override
  State<CallControlButton> createState() => _CallControlButtonState();
}

class _CallControlButtonState extends State<CallControlButton> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        color: call_control_color,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon:
            Icon(widget.isDisabled ? widget.disabledIcon : widget.enabledIcon),
        onPressed: widget.isDisabled ? widget.onDisabled : widget.onEnabled,
      ),
    );
  }
}

class CallInvitation extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const CallInvitation(
      {super.key, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        CallButton(
          onPressed: onAccept,
        ),
        DeclineButton(
          onPressed: onDecline,
        ),
      ],
    );
  }
}

abstract class BaseButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String iconPath;

  const BaseButton(
      {super.key, required this.onPressed, required this.iconPath});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: SvgPicture.asset(
        iconPath,
        width: iconSize,
        height: iconSize,
      ),
    );
  }
}

class CallButton extends BaseButton {
  const CallButton({super.key, required VoidCallback onPressed})
      : super(onPressed: onPressed, iconPath: green_call_icon);
}

class DeclineButton extends BaseButton {
  const DeclineButton({super.key, required VoidCallback onPressed})
      : super(onPressed: onPressed, iconPath: red_decline_icon);
}
