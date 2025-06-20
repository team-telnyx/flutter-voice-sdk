import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/model/call_history_entry.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/service/call_history_service.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';

class CallHistoryBottomSheet extends StatefulWidget {
  const CallHistoryBottomSheet({super.key});

  @override
  State<CallHistoryBottomSheet> createState() => _CallHistoryBottomSheetState();
}

class _CallHistoryBottomSheetState extends State<CallHistoryBottomSheet> {
  List<CallHistoryEntry> _callHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCallHistory();
  }

  Future<void> _loadCallHistory() async {
    final profileProvider = context.read<ProfileProvider>();
    final selectedProfile = profileProvider.selectedProfile;

    if (selectedProfile != null) {
      final profileId = _getProfileId(selectedProfile);
      final history = await CallHistoryService.getCallHistory(profileId);

      if (mounted) {
        setState(() {
          _callHistory = history;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getProfileId(dynamic profile) {
    // Create a unique identifier for the profile
    if (profile.isTokenLogin) {
      return 'token_${profile.token.hashCode}';
    } else {
      return 'sip_${profile.sipUser.hashCode}';
    }
  }

  void _onCallHistoryEntryTap(CallHistoryEntry entry) {
    // Close the bottom sheet
    Navigator.of(context).pop();

    // Initiate call to the destination
    context.read<TelnyxClientViewModel>().call(entry.destination);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(spacingL),
          topRight: Radius.circular(spacingL),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: spacingM),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(spacingL),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Call History',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _callHistory.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: spacingM),
                        Text(
                          'No call history',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _callHistory.length,
                    itemBuilder: (context, index) {
                      final entry = _callHistory[index];
                      return CallHistoryListItem(
                        entry: entry,
                        onTap: () => _onCallHistoryEntryTap(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class CallHistoryListItem extends StatelessWidget {
  final CallHistoryEntry entry;
  final VoidCallback onTap;

  const CallHistoryListItem({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: entry.direction == CallDirection.incoming
            ? Colors.green.shade100
            : Colors.blue.shade100,
        child: Icon(
          entry.direction == CallDirection.incoming
              ? Icons.call_received
              : Icons.call_made,
          color: entry.direction == CallDirection.incoming
              ? Colors.green.shade700
              : Colors.blue.shade700,
        ),
      ),
      title: Text(
        entry.displayDestination,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${entry.direction == CallDirection.incoming ? 'Incoming' : 'Outgoing'} • ${entry.formattedTime}',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      trailing: Icon(Icons.call, color: Colors.grey.shade600),
      onTap: onTap,
    );
  }
}
