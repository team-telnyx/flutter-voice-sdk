import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/login/bottom_sheet/profile_switcher_bottom_sheet.dart';

class LoginControls extends StatefulWidget {
  const LoginControls({super.key});

  @override
  State<LoginControls> createState() => _LoginControlsState();
}

class _LoginControlsState extends State<LoginControls> {
  void _showProfileSwitcher() {
    showModalBottomSheet(
      context: context,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Profile', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: spacingS),
        Row(
          children: <Widget>[
            Text(selectedProfile?.name ?? 'No profile selected'),
            SizedBox(width: spacingS),
            TextButton(
              onPressed: _showProfileSwitcher,
              child: const Text('Switch Profile'),
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: selectedProfile != null
                ? () {
                    final viewModel = context.read<TelnyxClientViewModel>();
                    if (selectedProfile.isTokenLogin) {
                      viewModel.loginWithToken(
                        selectedProfile.toTelnyxConfig() as TokenConfig,
                      );
                    } else {
                      viewModel.login(
                        selectedProfile.toTelnyxConfig() as CredentialConfig,
                      );
                    }
                  }
                : null,
            child: const Text('Connect'),
          ),
        ),
      ],
    );
  }
}
