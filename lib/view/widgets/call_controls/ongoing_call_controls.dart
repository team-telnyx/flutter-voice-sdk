import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/buttons/call_buttons.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/call_quality_indicator.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/dialpad_widget.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/transcript_dialog.dart';

class OnGoingCallControls extends StatelessWidget {
  const OnGoingCallControls({super.key});

  void _showTranscriptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: TranscriptDialog(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAssistantMode = context.select<TelnyxClientViewModel, bool>(
      (txClient) => txClient.isAssistantMode,
    );

    return Column(
      children: [
        // Call quality indicator
        Align(
          alignment: Alignment.centerLeft,
          child: const CallQualityIndicator(),
        ),
        SizedBox(height: spacingM),
        // Row of action buttons on top
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CallControlButton(
              enabledIcon: Icons.mic_off,
              disabledIcon: Icons.mic,
              isDisabled: context.select<TelnyxClientViewModel, bool>(
                (txClient) => txClient.muteState,
              ),
              onToggle: () {
                context.read<TelnyxClientViewModel>().muteUnmute();
              },
            ),
            CallControlButton(
              enabledIcon: Icons.volume_off,
              disabledIcon: Icons.volume_up,
              isDisabled: context.select<TelnyxClientViewModel, bool>(
                (txClient) => txClient.speakerPhoneState,
              ),
              onToggle: () {
                context.read<TelnyxClientViewModel>().toggleSpeakerPhone();
              },
            ),
            CallControlButton(
              enabledIcon: Icons.pause,
              disabledIcon: Icons.play_arrow,
              isDisabled: context.select<TelnyxClientViewModel, bool>(
                (txClient) => txClient.holdState,
              ),
              onToggle: () {
                context.read<TelnyxClientViewModel>().holdUnhold();
              },
            ),
            if (!isAssistantMode)
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
            if (isAssistantMode)
              CallControlButton(
                enabledIcon: Icons.chat,
                disabledIcon: Icons.chat,
                isDisabled: false,
                onToggle: () {
                  _showTranscriptDialog(context);
                },
              ),
          ],
        ),
        SizedBox(height: spacingM),
        // Decline/End call button underneath
        DeclineButton(
          onPressed: () {
            context.read<TelnyxClientViewModel>().endCall();
          },
        ),
      ],
    );
  }
}
