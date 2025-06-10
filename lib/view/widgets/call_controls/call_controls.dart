import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_flutter_webrtc/utils/version_utils.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/buttons/call_buttons.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/call_invitation.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/ongoing_call_controls.dart';
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';

class CallControls extends StatefulWidget {
  const CallControls({super.key});

  @override
  State<CallControls> createState() => _CallControlsState();
}

class _CallControlsState extends State<CallControls> {
  final _destinationController = TextEditingController();
  String _versionString = '';

  @override
  void initState() {
    super.initState();
    _loadVersionString();
  }

  Future<void> _loadVersionString() async {
    final versionString = await VersionUtils.getVersionString();
    setState(() {
      _versionString = versionString;
    });
  }

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
      children: <Widget>[
        // Main content area
        Column(
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
            _buildCallQualityMetrics(metrics),
          ],
        ),
        
        // Spacer to push disconnect button and version to bottom (only when idle)
        if (clientState == CallStateStatus.idle) const Spacer(),
        
        // Disconnect button at the bottom when connected but idle
        if (clientState == CallStateStatus.idle)
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    context.read<TelnyxClientViewModel>().disconnect();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Disconnect'),
                ),
              ),
              const SizedBox(height: spacingS),
              Text(
                _versionString,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
