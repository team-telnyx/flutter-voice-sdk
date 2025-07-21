import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/call_controls.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/common/bottom_action_widget.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/header/control_header.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/login/login_controls.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    askForNotificationPermission();
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

  void handleOptionClick(String value) {
    switch (value) {
      case 'Export Logs':
        Provider.of<TelnyxClientViewModel>(context, listen: false).exportLogs();
        break;
      case 'Disable Push Notifications':
        Provider.of<TelnyxClientViewModel>(
          context,
          listen: false,
        ).disablePushNotifications();
        break;
      case 'Enable Debugging':
      case 'Disable Debugging':
        Provider.of<ProfileProvider>(context, listen: false).toggleDebugMode();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientState = context.select<TelnyxClientViewModel, CallStateStatus>(
      (txClient) => txClient.callState,
    );

    final profileProvider = context.watch<ProfileProvider>();
    final selectedProfile = profileProvider.selectedProfile;

    final errorMessage = context.select<TelnyxClientViewModel, String?>(
      (viewModel) => viewModel.errorDialogMessage,
    );

    if (errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () {
                  context.read<TelnyxClientViewModel>().clearErrorDialog();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          // Show different menu options based on client state
          if (clientState == CallStateStatus.idle)
            PopupMenuButton<String>(
              onSelected: handleOptionClick,
              itemBuilder: (BuildContext context) {
                return {'Export Logs', 'Disable Push Notifications'}.map((
                  String choice,
                ) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(choice),
                  );
                }).toList();
              },
            )
          else if (clientState == CallStateStatus.disconnected &&
              selectedProfile != null)
            PopupMenuButton<String>(
              onSelected: handleOptionClick,
              itemBuilder: (BuildContext context) {
                final debugToggleText = selectedProfile.isDebug
                    ? 'Disable Debugging'
                    : 'Enable Debugging';
                return {'Export Logs', debugToggleText}.map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(choice),
                  );
                }).toList();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: spacingXXL,
            vertical: spacingXS,
          ),
          child: Column(
            children: [
              const ControlHeaders(),
              const SizedBox(height: spacingS),
              if (clientState == CallStateStatus.disconnected)
                const LoginControls()
              else if (clientState == CallStateStatus.connectingToCall)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Connecting to call...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                )
              else
                const CallControls(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: clientState == CallStateStatus.idle
          ? Padding(
              padding: const EdgeInsets.all(spacingXXL),
              child: BottomConnectionActionWidget(
                buttonTitle: 'Disconnect',
                onPressed: () => {
                  context.read<TelnyxClientViewModel>().disconnect(),
                },
              ),
            )
          : clientState == CallStateStatus.disconnected
              ? // Connect Bottom Action widget positioned at the bottom
              Consumer<TelnyxClientViewModel>(
                  builder: (context, viewModel, child) {
                    final profileProvider = context.watch<ProfileProvider>();
                    final selectedProfile = profileProvider.selectedProfile;
                    return Padding(
                      padding: const EdgeInsets.all(spacingXXL),
                      child: BottomConnectionActionWidget(
                        buttonTitle: 'Connect',
                        isLoading: viewModel.loggingIn,
                        onPressed: selectedProfile != null
                            ? () async {
                                final config =
                                    await selectedProfile.toTelnyxConfig();
                                if (config is TokenConfig) {
                                  viewModel.loginWithToken(config);
                                } else if (config is CredentialConfig) {
                                  viewModel.login(config);
                                }
                              }
                            : null,
                      ),
                    );
                  },
                )
              : null,
    );
  }
}
