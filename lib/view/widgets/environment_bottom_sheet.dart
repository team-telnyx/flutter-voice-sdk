import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';

/// Bottom sheet for switching between development and production environments.
///
/// This allows users to switch between development and production TURN/STUN servers.
/// The environment switcher is only available when the client is disconnected.
class EnvironmentBottomSheet extends StatelessWidget {
  const EnvironmentBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final isDevEnvironment = profileProvider.isDevEnvironment;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Environment Options',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: spacingM),
              Text(
                'Select the server environment for TURN/STUN servers.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: spacingL),
              _EnvironmentOption(
                title: 'Development Environment',
                subtitle: 'Uses turndev.telnyx.com and stundev.telnyx.com',
                isSelected: isDevEnvironment,
                onTap: () {
                  profileProvider.setDevEnvironment(true);
                  context.read<TelnyxClientViewModel>().setDevEnvironment(true);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Switched to Development Environment'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: spacingM),
              _EnvironmentOption(
                title: 'Production Environment',
                subtitle: 'Uses turn.telnyx.com and stun.telnyx.com',
                isSelected: !isDevEnvironment,
                onTap: () {
                  profileProvider.setDevEnvironment(false);
                  context.read<TelnyxClientViewModel>().setDevEnvironment(false);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Switched to Production Environment'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: spacingL),
              Container(
                padding: const EdgeInsets.all(spacingM),
                decoration: BoxDecoration(
                  color: isDevEnvironment
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDevEnvironment ? Colors.orange : Colors.green,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDevEnvironment ? Icons.developer_mode : Icons.cloud,
                      color: isDevEnvironment ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: spacingS),
                    Expanded(
                      child: Text(
                        isDevEnvironment
                            ? 'Currently using Development servers'
                            : 'Currently using Production servers',
                        style: TextStyle(
                          color: isDevEnvironment ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnvironmentOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _EnvironmentOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(spacingM),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.05)
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).primaryColor,
              ),
          ],
        ),
      ),
    );
  }
}
