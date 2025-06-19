import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/model/profile_model.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/login/bottom_sheet/add_profile_form.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/login/bottom_sheet/profile_list.dart';

class ProfileSwitcherBottomSheet extends StatefulWidget {
  const ProfileSwitcherBottomSheet({super.key});

  @override
  State<ProfileSwitcherBottomSheet> createState() =>
      _ProfileSwitcherBottomSheetState();
}

class _ProfileSwitcherBottomSheetState
    extends State<ProfileSwitcherBottomSheet> {
  bool _isAddingProfile = false;
  Profile? _selectedProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      padding: const EdgeInsets.all(spacingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: spacingS),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Existing Profiles',
                  style: TextStyle(
                    fontSize: fontSizeL,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          if (!_isAddingProfile)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isAddingProfile = true;
                });
              },
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text(
                'Add new profile',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(spacingXXL),
                ),
              ),
            ),
          const SizedBox(height: spacingM),
          if (_isAddingProfile)
            AddProfileForm(
              onCancelPressed: () => {
                setState(() {
                  _isAddingProfile = false;
                }),
              },
              existingProfile: _selectedProfile,
            )
          else
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProfileList(
                    onProfileEditSelected: (profile) => {
                      setState(() {
                        _selectedProfile = profile;
                        _isAddingProfile = true;
                      }),
                    },
                  ),
                  const SizedBox(height: spacingL),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: spacingM),
                      ElevatedButton(
                        onPressed:
                            context.watch<ProfileProvider>().selectedProfile !=
                                null
                            ? () => Navigator.pop(context)
                            : null,
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
