import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/model/profile_model.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/asset_paths.dart';

class ProfileList extends StatelessWidget {
  final void Function(Profile) onProfileEditSelected;
  const ProfileList({Key? key, required this.onProfileEditSelected})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        if (provider.profiles.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No profiles yet'),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          itemCount: provider.profiles.length,
          itemBuilder: (context, index) {
            final profile = provider.profiles[index];
            final isSelected =
                provider.selectedProfile?.sipCallerIDName ==
                profile.sipCallerIDName;

            return ListTile(
              title: Text(profile.sipCallerIDName),
              subtitle: Text(profile.isTokenLogin ? 'Token' : 'Credentials'),
              selected: isSelected,
              selectedTileColor: Theme.of(context).colorScheme.surface,
              leading: Icon(
                profile.isTokenLogin ? Icons.key : Icons.person,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).iconTheme.color,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: SvgPicture.asset(edit_icon, width: 16, height: 16),
                    onPressed: () => onProfileEditSelected(profile),
                  ),
                  IconButton(
                    icon: SvgPicture.asset(delete_icon, width: 16, height: 16),
                    onPressed: () =>
                        provider.removeProfile(profile.sipCallerIDName),
                  ),
                ],
              ),
              onTap: () => provider.selectProfile(profile.sipCallerIDName),
            );
          },
        );
      },
    );
  }
}
