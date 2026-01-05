import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/call_controls.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/codec_selector_dialog.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/audio_constraints_dialog.dart';
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
  final TextEditingController _targetIdController = TextEditingController();
  bool _hasInitializedEnvironment = false;

  @override
  void initState() {
    super.initState();
    askForNotificationPermission();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitializedEnvironment) {
      _hasInitializedEnvironment = true;
      // Schedule the environment initialization after the build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final profileProvider = context.read<ProfileProvider>();
        context.read<TelnyxClientViewModel>()
          ..setDevEnvironment(profileProvider.isDevEnvironment);
      });
    }
  }

  @override
  void dispose() {
    _targetIdController.dispose();
    super.dispose();
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

  void _showAssistantLoginDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Assistant Login'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the Assistant Target ID:'),
              const SizedBox(height: 16),
              TextField(
                controller: _targetIdController,
                decoration: const InputDecoration(
                  labelText: 'Target ID',
                  hintText: 'e.g., assistant-123',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final targetId = _targetIdController.text.trim();
                if (targetId.isNotEmpty) {
                  Navigator.of(context).pop();
                  Provider.of<TelnyxClientViewModel>(context, listen: false)
                      .anonymousLogin(targetId: targetId);
                  _targetIdController.clear();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid Target ID'),
                    ),
                  );
                }
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  void handleOptionClick(String value) {
    switch (value) {
      case 'Audio Codecs':
        _showCodecSelectorDialog();
        break;
      case 'Audio Constraints':
        _showAudioConstraintsDialog();
        break;
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
      case 'Enable Trickle ICE':
      case 'Disable Trickle ICE':
        Provider.of<TelnyxClientViewModel>(context, listen: false)
            .toggleTrickleIce();
        break;
      case 'Assistant Login':
        _showAssistantLoginDialog();
        break;
      case 'Force ICE Renegotiation':
        Provider.of<TelnyxClientViewModel>(context, listen: false)
            .forceIceRenegotiation();
        break;
      case 'Start Call Muted On':
      case 'Start Call Muted Off':
        _toggleMuteOnStart();
        break;
    }
  }

  void _toggleMuteOnStart() {
    final viewModel =
        Provider.of<TelnyxClientViewModel>(context, listen: false);
    final newState = !viewModel.mutedMicOnStart;
    viewModel.setMutedMicOnStart(newState);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newState ? 'Start Call Muted: On' : 'Start Call Muted: Off',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showCodecSelectorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const CodecSelectorDialog();
      },
    );
  }

  void _showAudioConstraintsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const AudioConstraintsDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientState = context.select<TelnyxClientViewModel, CallStateStatus>(
          (txClient) => txClient.callState,
    );

    final profileProvider = context.watch<ProfileProvider>();
    final selectedProfile = profileProvider.selectedProfile;

    final clientViewModel = context.watch<TelnyxClientViewModel>();
    final useTrickleIce = clientViewModel.useTrickleIce;

    final errorMessage = context.select<TelnyxClientViewModel, String?>(
          (viewModel) => viewModel.errorDialogMessage,
    );

    if (errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) =>
              AlertDialog(
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
            Consumer<TelnyxClientViewModel>(
              builder: (context, viewModel, child) {
                final muteOnStartText = viewModel.mutedMicOnStart
                    ? 'Start Call Muted On'
                    : 'Start Call Muted Off';
                final trickleIceToggleText = useTrickleIce
                    ? 'Disable Trickle ICE'
                    : 'Enable Trickle ICE';
                return PopupMenuButton<String>(
                  onSelected: handleOptionClick,
                  itemBuilder: (BuildContext context) {
                    return [
                      muteOnStartText,
                      trickleIceToggleText,
                      'Audio Codecs',
                      'Audio Constraints',
                      'Export Logs',
                      'Disable Push Notifications',
                      'Force ICE Renegotiation',
                    ].map((String choice) {
                      return PopupMenuItem<String>(
                        value: choice,
                        child: Text(choice),
                      );
                    }).toList();
                  },
                );
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
                return [
                  'Export Logs',
                  debugToggleText,
                  'Assistant Login',
                  'Force ICE Renegotiation',
                ].map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(choice),
                  );
                }).toList();
              },
            )
          else if (clientState == CallStateStatus.ongoingCall ||
              clientState == CallStateStatus.ringing ||
              clientState == CallStateStatus.ongoingInvitation ||
              clientState == CallStateStatus.connectingToCall)
            PopupMenuButton<String>(
              onSelected: handleOptionClick,
              itemBuilder: (BuildContext context) {
                return [
                  'Force ICE Renegotiation',
                  'Export Logs',
                ].map((String choice) {
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
                                // Apply environment setting before connecting
                                final profileProvider =
                                    context.read<ProfileProvider>();
                                viewModel.setDevEnvironment(
                                  profileProvider.isDevEnvironment,
                                );

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
