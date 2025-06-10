import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/version_utils.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/login/bottom_sheet/profile_switcher_bottom_sheet.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';

class LoginControls extends StatefulWidget {
  const LoginControls({super.key});

  @override
  State<LoginControls> createState() => _LoginControlsState();
}

class _LoginControlsState extends State<LoginControls> {
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

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final selectedProfile = profileProvider.selectedProfile;

    return Column(
      children: <Widget>[
        // Profile section at the top
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Profile', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: spacingXS),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(selectedProfile?.sipCallerIDName ?? 'No profile selected'),
                ),
                const SizedBox(width: spacingS),
                OutlinedButton(
                  onPressed: _showProfileSwitcher,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(spacingS),
                    ),
                  ),
                  child: const Text('Switch Profile'),
                ),
              ],
            ),
          ],
        ),
        
        // Spacer to push connect button and version to bottom
        const Spacer(),
        
        // Connect button at the bottom
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: selectedProfile != null
                ? () async {
                    final viewModel = context.read<TelnyxClientViewModel>();
                    final config = await selectedProfile.toTelnyxConfig();
                    if (config is TokenConfig) {
                      viewModel.loginWithToken(config);
                    } else if (config is CredentialConfig) {
                      viewModel.login(config);
                    }
                  }
                : null,
            child: Consumer<TelnyxClientViewModel>(
              builder: (context, provider, child) {
                if (provider.loggingIn) {
                  return SizedBox(
                    width: spacingXL,
                    height: spacingXL,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  );
                } else {
                  return const Text('Connect');
                }
              },
            ),
          ),
        ),
        
        // Version information at the very bottom
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
    );
  }
}
