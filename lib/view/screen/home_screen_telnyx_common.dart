import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/provider/telnyx_common_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/call_controls_telnyx_common.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/common/bottom_action_widget.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/header/control_header_telnyx_common.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/login/login_controls_telnyx_common.dart';
import 'package:telnyx_common/telnyx_common.dart';

/// Home screen that uses telnyx_common module instead of direct telnyx_webrtc integration.
/// 
/// This screen demonstrates the migration from the legacy TelnyxClientViewModel
/// to the new TelnyxCommonProvider that wraps the telnyx_common module.
class HomeScreenTelnyxCommon extends StatefulWidget {
  const HomeScreenTelnyxCommon({super.key});

  @override
  State<HomeScreenTelnyxCommon> createState() => _HomeScreenTelnyxCommonState();
}

class _HomeScreenTelnyxCommonState extends State<HomeScreenTelnyxCommon> {
  @override
  void initState() {
    super.initState();
    askForNotificationPermission();
    _setupAutoLogin();
  }

  Future<void> askForNotificationPermission() async {
    if (!kIsWeb) {
      await FlutterCallkitIncoming.requestNotificationPermission(
        'notification',
      );
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    }
  }

  Future<void> _setupAutoLogin() async {
    // TODO: Implement auto-login using saved credentials
    // This would read from SharedPreferences and automatically connect
    // if valid credentials are found
  }

  void handleOptionClick(String value) {
    final provider = Provider.of<TelnyxCommonProvider>(context, listen: false);
    
    switch (value) {
      case 'Export Logs':
        // TODO: Implement log export functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log export not yet implemented')),
        );
        break;
      case 'Disable Push Notifications':
        // TODO: Implement push notification disable
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Push notification disable not yet implemented')),
        );
        break;
      case 'Enable Push Notifications':
        // TODO: Implement push notification enable
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Push notification enable not yet implemented')),
        );
        break;
      case 'Logout':
        provider.disconnect();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<TelnyxCommonProvider>(
        builder: (context, provider, child) {
          return SafeArea(
            child: Column(
              children: [
                // Header with connection status and controls
                ControlHeaderTelnyxCommon(
                  onOptionSelected: handleOptionClick,
                ),
                
                // Main content area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(Dimensions.paddingMedium),
                    child: _buildMainContent(provider),
                  ),
                ),
                
                // Bottom action area
                const BottomActionWidget(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(TelnyxCommonProvider provider) {
    // Show login controls if not connected
    if (!provider.registered) {
      return const LoginControlsTelnyxCommon();
    }
    
    // Show call controls if connected
    return const CallControlsTelnyxCommon();
  }
}