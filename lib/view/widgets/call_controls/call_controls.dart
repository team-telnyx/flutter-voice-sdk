import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/asset_paths.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/dialpad_widget.dart';

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
        else if (clientState == CallStateStatus.ongoingCall)
          Center(
            child: OnGoingCallControls(),
          ),
      ],
    );
  }
}

class OnGoingCallControls extends StatelessWidget {
  const OnGoingCallControls({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CallControlButton(
              enabledIcon: Icons.mic,
              disabledIcon: Icons.mic_off,
              isDisabled: context.select<TelnyxClientViewModel, bool>(
                (txClient) => txClient.muteState,
              ),
              onToggle: () {
                context.read<TelnyxClientViewModel>().muteUnmute();
              },
            ),
            DeclineButton(
              onPressed: () {
                context.read<TelnyxClientViewModel>().endCall();
              },
            ),
            CallControlButton(
              enabledIcon: Icons.volume_up,
              disabledIcon: Icons.volume_off,
              isDisabled: context.select<TelnyxClientViewModel, bool>(
                (txClient) => txClient.speakerPhoneState,
              ),
              onToggle: () {
                context.read<TelnyxClientViewModel>().toggleSpeakerPhone();
              },
            ),
          ],
        ),
        SizedBox(height: spacingM),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CallControlButton(
              enabledIcon: Icons.play_arrow,
              disabledIcon: Icons.pause,
              isDisabled: context.select<TelnyxClientViewModel, bool>(
                (txClient) => txClient.holdState,
              ),
              onToggle: () {
                context.read<TelnyxClientViewModel>().holdUnhold();
              },
            ),
            SizedBox(width: iconSize),
            CallControlButton(
              enabledIcon: Icons.dialpad,
              disabledIcon: Icons.dialpad,
              isDisabled: false,
              onToggle: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: DialPad(
                        onDigitPressed: (digit) {
                          context.read<TelnyxClientViewModel>().dtmf(digit);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class CallControlButton extends StatefulWidget {
  final IconData enabledIcon;
  final IconData disabledIcon;
  final bool isDisabled;
  final VoidCallback onToggle;

  const CallControlButton({
    super.key,
    required this.enabledIcon,
    required this.disabledIcon,
    required this.isDisabled,
    required this.onToggle,
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
        onPressed: widget.onToggle,
      ),
    );
  }
}

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

abstract class BaseButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String iconPath;

  const BaseButton({
    super.key,
    required this.onPressed,
    required this.iconPath,
  });

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
