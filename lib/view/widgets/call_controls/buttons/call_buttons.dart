import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:telnyx_flutter_webrtc/utils/asset_paths.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';

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
