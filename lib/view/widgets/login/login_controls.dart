import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/common/bottom_action_widget.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/login/bottom_sheet/profile_switcher_bottom_sheet.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';

class LoginControls extends StatefulWidget {
  const LoginControls({super.key});

  @override
  State<LoginControls> createState() => _LoginControlsState();
}

class _LoginControlsState extends State<LoginControls> {
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
                  Text(selectedProfile?.sipCallerIDName ??
                      'No profile selected'),
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
            ],
          ),

          // Bottom action widget positioned at the bottom
          Consumer<TelnyxClientViewModel>(
            builder: (context, viewModel, child) {
              return BottomActionWidget(
                buttonTitle: 'Connect',
                isLoading: viewModel.loggingIn,
                onPressed: selectedProfile != null
                    ? () async {
                        final config = await selectedProfile.toTelnyxConfig();
                        if (config is TokenConfig) {
                          viewModel.loginWithToken(config);
                        } else if (config is CredentialConfig) {
                          viewModel.login(config);
                        }
                      }
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}
