import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/buttons/call_buttons.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/call_invitation.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/ongoing_call_controls.dart';
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';

class DestinationToggle extends StatelessWidget {
  final bool isPhoneNumber;
  final ValueChanged<bool> onToggleChanged;

  const DestinationToggle({
    Key? key,
    required this.isPhoneNumber,
    required this.onToggleChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onToggleChanged(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: spacingM, horizontal: spacingL),
                decoration: BoxDecoration(
                  color: !isPhoneNumber ? active_text_field_color : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Text(
                  'SIP Address',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !isPhoneNumber ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onToggleChanged(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: spacingM, horizontal: spacingL),
                decoration: BoxDecoration(
                  color: isPhoneNumber ? active_text_field_color : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Text(
                  'Phone Number',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isPhoneNumber ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CallControls extends StatefulWidget {
  const CallControls({super.key});

  @override
  State<CallControls> createState() => _CallControlsState();
}

class _CallControlsState extends State<CallControls> {
  final _destinationController = TextEditingController();
  bool _isPhoneNumber = true;

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

    final metrics = context.select<TelnyxClientViewModel, CallQualityMetrics?>(
      (txClient) => txClient.callQualityMetrics,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Toggle section - only visible when idle
        if (clientState == CallStateStatus.idle) ...[
          DestinationToggle(
            isPhoneNumber: _isPhoneNumber,
            onToggleChanged: (value) {
              setState(() {
                _isPhoneNumber = value;
                _destinationController.clear(); // Clear input when switching
              });
            },
          ),
          const SizedBox(height: spacingM),
        ],
        Text('Destination', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: spacingXS),
        Padding(
          padding: const EdgeInsets.all(spacingXS),
          child: TextFormField(
            readOnly: clientState != CallStateStatus.idle,
            enabled: clientState == CallStateStatus.idle,
            controller: _destinationController,
            keyboardType: _isPhoneNumber ? TextInputType.phone : TextInputType.text,
            inputFormatters: _isPhoneNumber 
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s\(\)]'))]
                : [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9@\.\-_]'))],
            decoration: InputDecoration(
              hintStyle: Theme.of(context).textTheme.labelSmall,
              hintText: _isPhoneNumber 
                  ? '+E164 phone number (e.g., +35387718911)'
                  : 'SIP address (e.g., squadwebrtc)',
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
        _buildCallQualityMetrics(metrics),
      ],
    );
  }

  Widget _buildCallQualityMetrics(CallQualityMetrics? callQualityMetrics) {
    if (callQualityMetrics == null) return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: Color(0xFFF5F3E4), // Custom background color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0), // Rounded edges
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent, // Remove ExpansionTile divider
          ),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            childrenPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            title: Text(
              'Call Quality Metrics',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            children: [
              _buildMetricRow('Jitter', '${callQualityMetrics.jitter} ms'),
              _buildMetricRow('RTT', '${callQualityMetrics.rtt} ms'),
              _buildMetricRow('MOS', '${callQualityMetrics.mos}'),
              _buildMetricRow('Quality', callQualityMetrics.quality.toString()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
