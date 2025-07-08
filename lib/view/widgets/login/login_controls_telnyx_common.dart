import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/provider/telnyx_common_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/login/bottom_sheet/profile_switcher_bottom_sheet.dart';
import 'package:telnyx_common/telnyx_common.dart';

/// Login controls component that uses telnyx_common provider for authentication.
class LoginControlsTelnyxCommon extends StatefulWidget {
  const LoginControlsTelnyxCommon({super.key});

  @override
  State<LoginControlsTelnyxCommon> createState() => _LoginControlsTelnyxCommonState();
}

class _LoginControlsTelnyxCommonState extends State<LoginControlsTelnyxCommon> {
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

  Future<void> _connectWithProfile() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final telnyxProvider = Provider.of<TelnyxCommonProvider>(context, listen: false);
    final selectedProfile = profileProvider.selectedProfile;

    if (selectedProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a profile first')),
      );
      return;
    }

    try {
      // Create configuration based on profile type
      if (selectedProfile.sipToken != null && selectedProfile.sipToken!.isNotEmpty) {
        // Token-based authentication
        final config = TokenConfig(
          sipToken: selectedProfile.sipToken!,
          sipCallerIDName: selectedProfile.sipCallerIDName,
          sipCallerIDNumber: selectedProfile.sipCallerIDNumber,
          notificationToken: selectedProfile.notificationToken,
        );
        await telnyxProvider.connectWithToken(config);
      } else {
        // Credential-based authentication
        final config = CredentialConfig(
          sipUser: selectedProfile.sipUser,
          sipPassword: selectedProfile.sipPassword,
          sipCallerIDName: selectedProfile.sipCallerIDName,
          sipCallerIDNumber: selectedProfile.sipCallerIDNumber,
          notificationToken: selectedProfile.notificationToken,
        );
        await telnyxProvider.connectWithCredentials(config);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProfileProvider, TelnyxCommonProvider>(
      builder: (context, profileProvider, telnyxProvider, child) {
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
                      Expanded(
                        child: Text(
                          selectedProfile?.sipCallerIDName ?? 'No profile selected',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: spacingM),
                      ElevatedButton(
                        onPressed: _showProfileSwitcher,
                        child: const Text('Select Profile'),
                      ),
                    ],
                  ),
                  
                  // Show profile details if selected
                  if (selectedProfile != null) ...[
                    const SizedBox(height: spacingM),
                    _buildProfileDetails(selectedProfile),
                  ],
                ],
              ),
              
              // Connection status and controls at the bottom
              Column(
                children: [
                  // Connection status
                  _buildConnectionStatus(telnyxProvider),
                  const SizedBox(height: spacingL),
                  
                  // Connect button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedProfile != null && !telnyxProvider.loggingIn
                          ? _connectWithProfile
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: spacingM),
                      ),
                      child: telnyxProvider.loggingIn
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: spacingS),
                                Text('Connecting...'),
                              ],
                            )
                          : const Text('Connect'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileDetails(dynamic selectedProfile) {
    return Container(
      padding: const EdgeInsets.all(spacingM),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Details',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: spacingS),
          _buildDetailRow('Name', selectedProfile.sipCallerIDName),
          _buildDetailRow('Number', selectedProfile.sipCallerIDNumber),
          if (selectedProfile.sipToken != null && selectedProfile.sipToken!.isNotEmpty)
            _buildDetailRow('Auth Type', 'Token')
          else
            _buildDetailRow('Auth Type', 'Credentials'),
          if (selectedProfile.sipUser.isNotEmpty)
            _buildDetailRow('SIP User', selectedProfile.sipUser),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(TelnyxCommonProvider provider) {
    String statusText;
    Color statusColor;
    
    switch (provider.connectionState) {
      case ConnectionState.connected:
        statusText = 'Connected to Telnyx';
        statusColor = Colors.green;
        break;
      case ConnectionState.connecting:
        statusText = 'Connecting to Telnyx...';
        statusColor = Colors.orange;
        break;
      case ConnectionState.disconnected:
        statusText = 'Disconnected from Telnyx';
        statusColor = Colors.red;
        break;
      case ConnectionState.error:
        statusText = 'Connection error';
        statusColor = Colors.red;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(spacingM),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: spacingS),
          Expanded(
            child: Text(
              statusText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}