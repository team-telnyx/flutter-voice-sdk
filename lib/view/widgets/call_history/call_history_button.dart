import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_history/call_history_bottom_sheet.dart';

class CallHistoryButton extends StatelessWidget {
  const CallHistoryButton({super.key});

  void _showCallHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CallHistoryBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showCallHistory(context),
      icon: const Icon(
        Icons.history,
        size: 20,
      ),
      label: const Text('Call History'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(spacingS),
        ),
        side: BorderSide(
          color: Colors.grey.shade400,
          width: 1.5,
        ),
        foregroundColor: Colors.grey.shade700,
      ),
    );
  }
}