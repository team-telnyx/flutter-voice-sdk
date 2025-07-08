import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/provider/telnyx_common_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_history/call_history_button.dart';
import 'package:telnyx_common/telnyx_common.dart';

/// Call controls component that uses telnyx_common provider for call management.
class CallControlsTelnyxCommon extends StatefulWidget {
  const CallControlsTelnyxCommon({super.key});

  @override
  State<CallControlsTelnyxCommon> createState() => _CallControlsTelnyxCommonState();
}

class _CallControlsTelnyxCommonState extends State<CallControlsTelnyxCommon> {
  final TextEditingController _destinationController = TextEditingController();
  bool _isPhoneNumber = true;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TelnyxCommonProvider>(
      builder: (context, provider, child) {
        // Show different UI based on call state
        switch (provider.callState) {
          case CallStateStatus.idle:
            return _buildIdleControls(provider);
          case CallStateStatus.ringing:
          case CallStateStatus.ongoingInvitation:
            return _buildIncomingCallControls(provider);
          case CallStateStatus.connectingToCall:
            return _buildConnectingControls(provider);
          case CallStateStatus.ongoingCall:
            return _buildOngoingCallControls(provider);
          default:
            return _buildIdleControls(provider);
        }
      },
    );
  }

  Widget _buildIdleControls(TelnyxCommonProvider provider) {
    return Column(
      children: [
        // Destination input section
        _buildDestinationInput(),
        const SizedBox(height: spacingL),
        
        // Call button
        _buildCallButton(provider),
        const SizedBox(height: spacingL),
        
        // Call history button
        const CallHistoryButton(),
        
        // Error dialog if any
        if (provider.errorDialogMessage != null)
          _buildErrorDialog(provider),
      ],
    );
  }

  Widget _buildIncomingCallControls(TelnyxCommonProvider provider) {
    final activeCall = provider.activeCall;
    
    return Container(
      padding: const EdgeInsets.all(spacingL),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Icon(
            Icons.phone_in_talk,
            size: 64,
            color: Colors.blue[600],
          ),
          const SizedBox(height: spacingM),
          Text(
            'Incoming Call',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: spacingS),
          if (activeCall != null) ...[
            Text(
              'From: ${activeCall.callerNumber ?? activeCall.callerName ?? 'Unknown'}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: spacingM),
          ],
          
          // Answer/Decline buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Decline button
              ElevatedButton.icon(
                onPressed: () => provider.endCall(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: spacingL,
                    vertical: spacingM,
                  ),
                ),
                icon: const Icon(Icons.call_end),
                label: const Text('Decline'),
              ),
              
              // Answer button
              ElevatedButton.icon(
                onPressed: () => provider.acceptCall(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: spacingL,
                    vertical: spacingM,
                  ),
                ),
                icon: const Icon(Icons.call),
                label: const Text('Answer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingControls(TelnyxCommonProvider provider) {
    return Container(
      padding: const EdgeInsets.all(spacingL),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: spacingM),
          Text(
            'Connecting...',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: spacingS),
          if (provider.activeCall != null)
            Text(
              'To: ${provider.activeCall!.destination ?? 'Unknown'}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          const SizedBox(height: spacingM),
          
          // End call button
          ElevatedButton.icon(
            onPressed: () => provider.endCall(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.call_end),
            label: const Text('End Call'),
          ),
        ],
      ),
    );
  }

  Widget _buildOngoingCallControls(TelnyxCommonProvider provider) {
    final activeCall = provider.activeCall;
    
    return Container(
      padding: const EdgeInsets.all(spacingL),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Icon(
            Icons.phone_in_talk,
            size: 64,
            color: Colors.green[600],
          ),
          const SizedBox(height: spacingM),
          Text(
            'Call Active',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: spacingS),
          if (activeCall != null) ...[
            Text(
              activeCall.isIncoming
                  ? 'From: ${activeCall.callerNumber ?? activeCall.callerName ?? 'Unknown'}'
                  : 'To: ${activeCall.destination ?? 'Unknown'}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: spacingM),
          ],
          
          // Call control buttons
          _buildCallControlButtons(provider),
          const SizedBox(height: spacingM),
          
          // DTMF keypad toggle
          _buildDTMFSection(provider),
        ],
      ),
    );
  }

  Widget _buildDestinationInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Destination',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: spacingS),
        
        // Destination type toggle
        _buildDestinationToggle(),
        const SizedBox(height: spacingS),
        
        // Destination input field
        TextField(
          controller: _destinationController,
          keyboardType: _isPhoneNumber ? TextInputType.phone : TextInputType.text,
          inputFormatters: _isPhoneNumber
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s\(\)]'))]
              : null,
          decoration: InputDecoration(
            hintText: _isPhoneNumber
                ? 'Enter phone number (e.g., +1234567890)'
                : 'Enter SIP address (e.g., sip:user@domain.com)',
            border: const OutlineInputBorder(),
            prefixIcon: Icon(_isPhoneNumber ? Icons.phone : Icons.alternate_email),
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationToggle() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isPhoneNumber = false),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: spacingM,
                  horizontal: spacingL,
                ),
                decoration: BoxDecoration(
                  color: !_isPhoneNumber
                      ? active_text_field_color
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: const Text(
                  'SIP Address',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isPhoneNumber = true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: spacingM,
                  horizontal: spacingL,
                ),
                decoration: BoxDecoration(
                  color: _isPhoneNumber
                      ? active_text_field_color
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: const Text(
                  'Phone Number',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton(TelnyxCommonProvider provider) {
    final destination = _destinationController.text.trim();
    final isEnabled = destination.isNotEmpty && provider.registered;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? () => _makeCall(provider, destination) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: spacingM),
        ),
        icon: const Icon(Icons.call),
        label: const Text('Call'),
      ),
    );
  }

  Widget _buildCallControlButtons(TelnyxCommonProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute button
        _buildControlButton(
          icon: provider.muteState ? Icons.mic_off : Icons.mic,
          label: provider.muteState ? 'Unmute' : 'Mute',
          onPressed: provider.muteState ? provider.unmuteCall : provider.muteCall,
          isActive: provider.muteState,
        ),
        
        // Hold button
        _buildControlButton(
          icon: provider.holdState ? Icons.play_arrow : Icons.pause,
          label: provider.holdState ? 'Unhold' : 'Hold',
          onPressed: provider.holdState ? provider.unholdCall : provider.holdCall,
          isActive: provider.holdState,
        ),
        
        // Speaker button
        _buildControlButton(
          icon: provider.speakerPhoneState ? Icons.volume_up : Icons.volume_down,
          label: 'Speaker',
          onPressed: provider.toggleSpeakerPhone,
          isActive: provider.speakerPhoneState,
        ),
        
        // End call button
        _buildControlButton(
          icon: Icons.call_end,
          label: 'End',
          onPressed: provider.endCall,
          backgroundColor: Colors.red,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
    Color? backgroundColor,
  }) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? (isActive ? Colors.blue : Colors.grey[300]),
            foregroundColor: backgroundColor != null ? Colors.white : (isActive ? Colors.white : Colors.black),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(spacingM),
          ),
          child: Icon(icon),
        ),
        const SizedBox(height: spacingXS),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildDTMFSection(TelnyxCommonProvider provider) {
    return ExpansionTile(
      title: const Text('DTMF Keypad'),
      children: [
        _buildDTMFKeypad(provider),
      ],
    );
  }

  Widget _buildDTMFKeypad(TelnyxCommonProvider provider) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['*', '0', '#'],
    ];
    
    return Container(
      padding: const EdgeInsets.all(spacingM),
      child: Column(
        children: keys.map((row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(spacingXS),
                  child: ElevatedButton(
                    onPressed: () => provider.sendDTMF(key),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: spacingM),
                    ),
                    child: Text(
                      key,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildErrorDialog(TelnyxCommonProvider provider) {
    return Container(
      margin: const EdgeInsets.only(top: spacingM),
      padding: const EdgeInsets.all(spacingM),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red[600]),
          const SizedBox(width: spacingS),
          Expanded(
            child: Text(
              provider.errorDialogMessage!,
              style: TextStyle(color: Colors.red[600]),
            ),
          ),
          IconButton(
            onPressed: provider.clearErrorDialog,
            icon: const Icon(Icons.close),
            color: Colors.red[600],
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(TelnyxCommonProvider provider, String destination) async {
    try {
      await provider.newCall(destination);
      _destinationController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to make call: $e')),
      );
    }
  }
}