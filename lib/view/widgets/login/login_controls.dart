import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/login/bottom_sheet/profile_switcher_bottom_sheet.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';

class LoginControls extends StatefulWidget {
  const LoginControls({super.key});

  @override
  State<LoginControls> createState() => _LoginControlsState();
}

class _LoginControlsState extends State<LoginControls> {
  final TextEditingController _targetIdController = TextEditingController();

  void _showProfileSwitcher() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const ProfileSwitcherBottomSheet(),
      ),
    );
  }

  void _showAnonymousLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anonymous Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the AI Assistant ID to connect anonymously:'),
            const SizedBox(height: spacingM),
            TextField(
              controller: _targetIdController,
              decoration: const InputDecoration(
                labelText: 'Assistant ID',
                hintText: 'e.g., assistant_123',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_targetIdController.text.isNotEmpty) {
                context.read<TelnyxClientViewModel>().anonymousLogin(
                  targetId: _targetIdController.text,
                );
                Navigator.of(context).pop();
                _targetIdController.clear();
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _targetIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final selectedProfile = profileProvider.selectedProfile;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Profile section at the top
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Profile', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: spacingXS),
              Row(
                children: <Widget>[
                  Text(
                    selectedProfile?.sipCallerIDName ?? 'No profile selected',
                  ),
                  const SizedBox(width: spacingXXXXXL),
                  OutlinedButton(
                    onPressed: _showProfileSwitcher,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(spacingM),
                      ),
                    ),
                    child: const Text('Switch Profile'),
                  ),
                ],
              ),
              const SizedBox(height: spacingL),
              // Anonymous login section
              Text('Anonymous Login', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: spacingXS),
              Text(
                'Connect to AI assistants without authentication',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: spacingM),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showAnonymousLoginDialog,
                  icon: const Icon(Icons.smart_toy),
                  label: const Text('Connect to AI Assistant'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(spacingM),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
