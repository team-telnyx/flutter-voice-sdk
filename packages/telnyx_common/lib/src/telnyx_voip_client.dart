import 'dart:async';
import 'dart:convert'; // Added for jsonDecode
import 'dart:io'; // Added for Platform.isIOS
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:telnyx_common/telnyx_common.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_common/src/models/call.dart';
import 'package:telnyx_common/src/models/connection_state.dart';
import 'package:telnyx_common/src/internal/session/session_manager.dart';
import 'package:telnyx_common/src/internal/calls/call_state_controller.dart';
import 'package:telnyx_common/src/internal/push/push_notification_manager.dart';
import 'package:telnyx_common/src/internal/push/push_token_provider.dart';
import 'package:telnyx_common/src/internal/push/notification_display_service.dart';
import 'package:telnyx_common/src/internal/callkit/callkit_manager.dart';
import 'package:telnyx_common/utils/iterable_extensions.dart';
import 'package:telnyx_common/src/util/config_helper.dart';

/// The main public interface for the telnyx_common module.
///
/// This class serves as the Façade for the entire module, providing a simplified
/// API that completely hides the underlying complexity. It is the sole entry point
/// for developers using the telnyx_common package.
///
/// The TelnyxVoipClient is designed to be state-management agnostic, exposing
/// all observable state via Dart's native Stream<T>. This allows developers to
/// integrate it into their chosen state management solution naturally.
class TelnyxVoipClient {
  // Internal components
  late final SessionManager _sessionManager;
  late final CallStateController _callStateController;
  PushNotificationManager? _pushNotificationManager;
  CallKitManager? _callKitManager;

  // Configuration
  final PushNotificationManagerConfig _pushConfig;
  final bool _isBackgroundClient;
  bool _disposed = false;

  // Store configuration for push notification handling
  Config? _storedConfig;
  PushMetaData? _storedPushMetaData;
  Map<String, dynamic>? _storedPushPayload;

  // Flag to track if we're waiting for an invite after accepting from terminated state
  bool _waitingForInvite = false;

  /// Creates a new TelnyxVoipClient instance.
  ///
  /// [enableNativeUI] - Whether to enable native call UI integration.
  /// When enabled, the client will automatically show native incoming call
  /// screens and manage call UI through the system's call interface.
  ///
  /// [enableBackgroundHandling] - Whether to enable background push notification handling.
  ///
  /// [notificationConfig] - Optional configuration for notification display.
  ///
  /// [customTokenProvider] - Optional custom push token provider. If not provided,
  /// push token functionality will be utilize the [DefaultPushTokenProvider].
  ///
  /// [isBackgroundClient] - Whether this is a temporary background client created
  /// for handling push notifications when the app is terminated. Specifically around decline,
  /// where you don't want the entire app to launch. Background clients
  /// should be disposed after use, while main app clients should persist.
  TelnyxVoipClient({
    bool enableNativeUI = false,
    bool enableBackgroundHandling = true,
    NotificationConfig? notificationConfig,
    PushTokenProvider? customTokenProvider,
    bool isBackgroundClient = false,
  })  : _pushConfig = PushNotificationManagerConfig(
          enableNativeUI: enableNativeUI,
          enableBackgroundHandling: enableBackgroundHandling,
          notificationConfig: notificationConfig,
          customTokenProvider:
              customTokenProvider ?? DefaultPushTokenProvider(),
        ),
        _isBackgroundClient = isBackgroundClient {
    _initializeComponents();
  }

  /// Stream of connection state changes.
  ///
  /// Emits the current status of the connection to the Telnyx backend.
  /// Values include connecting, connected, disconnected, and error states.
  /// Listen to this to show connection indicators in your UI.
  Stream<ConnectionState> get connectionState =>
      _sessionManager.connectionState;

  /// Stream of all current calls.
  ///
  /// Emits a list of all current Call objects. Use this for applications
  /// that need to support multiple simultaneous calls (e.g., call waiting,
  /// conference calls).
  Stream<List<Call>> get calls => _callStateController.calls;

  /// Stream of the currently active call.
  ///
  /// A convenience stream that emits the currently active Call object.
  /// It emits null when no call is in progress. Ideal for applications
  /// that only handle a single call at a time.
  Stream<Call?> get activeCall => _callStateController.activeCall;

  /// Current connection state (synchronous access).
  ConnectionState get currentConnectionState => _sessionManager.currentState;

  /// Current list of calls (synchronous access).
  List<Call> get currentCalls => _callStateController.currentCalls;

  /// Current active call (synchronous access).
  Call? get currentActiveCall => _callStateController.currentActiveCall;

  /// Current push token (synchronous access).
  String? get currentPushToken => _pushNotificationManager?.currentToken;

  /// Current session ID (UUID) for this connection.
  String get sessionId => _sessionManager.sessionId;

  /// Disables push notifications for the current session.
  ///
  /// This method sends a request to the Telnyx backend to disable push
  /// notifications for the current registered device/session.
  void disablePushNotifications() {
    _sessionManager.disablePushNotifications();
  }

  /// Connects to the Telnyx platform using credential authentication.
  ///
  /// [config] - The credential configuration containing SIP username and password.
  ///
  /// Returns a Future that completes when the connection attempt is initiated.
  /// Listen to [connectionState] to monitor the actual connection status.
  Future<void> login(CredentialConfig config) async {
    if (_disposed) throw StateError('TelnyxVoipClient has been disposed');

    // Store the configuration for push notification handling
    _storedConfig = config;
    await ConfigHelper.saveConfig(config);

    // Initialize push notification manager if not already done
    await _ensurePushNotificationManagerInitialized();

    await _sessionManager.connectWithCredential(config);
  }

  /// Connects to the Telnyx platform using token authentication.
  ///
  /// [config] - The token configuration containing the authentication token.
  ///
  /// Returns a Future that completes when the connection attempt is initiated.
  /// Listen to [connectionState] to monitor the actual connection status.
  Future<void> loginWithToken(TokenConfig config) async {
    if (_disposed) throw StateError('TelnyxVoipClient has been disposed');

    // Store the configuration for push notification handling
    _storedConfig = config;
    await ConfigHelper.saveConfig(config);

    // Initialize push notification manager if not already done
    await _ensurePushNotificationManagerInitialized();

    await _sessionManager.connectWithToken(config);
  }

  /// Attempts to log in using a configuration stored on the device.
  ///
  /// This is useful for automatically reconnecting when the app starts.
  /// Returns `true` if a stored configuration was found and a login attempt
  /// was initiated, `false` otherwise.
  Future<bool> loginFromStoredConfig() async {
    if (_disposed) throw StateError('TelnyxVoipClient has been disposed');

    final config = await ConfigHelper.getConfig();
    if (config != null) {
      debugPrint(
          'TelnyxVoipClient: Found stored config, attempting to log in...');
      if (config is CredentialConfig) {
        await login(config);
      } else if (config is TokenConfig) {
        await loginWithToken(config);
      }
      return true;
    } else {
      debugPrint('TelnyxVoipClient: No stored config found.');
      return false;
    }
  }

  /// Disconnects from the Telnyx platform.
  ///
  /// This method terminates the connection, ends any active calls, and
  /// cleans up all related resources.
  Future<void> logout() async {
    if (_disposed) return;

    // Clear stored configuration
    _storedConfig = null;
    _storedPushMetaData = null;
    _storedPushPayload = null;
    _waitingForInvite = false;

    await _sessionManager.disconnect();
  }

  /// Initiates a new outgoing call.
  ///
  /// [destination] - The destination number or SIP URI to call.
  /// [debug] - Optional flag to enable call quality metrics for this call. When enabled, the onCallQualityMetrics callback will be triggered on the call object.
  ///
  /// Returns a Future that completes with the Call object once the
  /// invitation has been sent. The call's state can be monitored through
  /// the returned Call object's streams.
  Future<Call> newCall(
      {required String destination, bool debug = false}) async {
    if (_disposed) throw StateError('TelnyxVoipClient has been disposed');

    final call = await _callStateController.newCall(destination, debug);

    return call;
  }

  /// This is the unified entry point for all push notifications. It intelligently
  /// determines whether to show a new incoming call UI or to process an already
  /// actioned (accepted/declined) call upon app launch.
  Future<void> handlePushNotification(Map<String, dynamic> payload) async {
    if (_disposed) throw StateError('TelnyxVoipClient has been disposed');

    // Ensure the push manager is ready, as we might need it for the UI.
    await _ensurePushNotificationManagerInitialized();

    // The gateway expects the metadata to be under a 'metadata' key.
    final metadataJson = payload['metadata'];
    if (metadataJson == null) {
      debugPrint(
          'TelnyxVoipClient: No metadata in push payload, cannot process.');
      return;
    }

    final Map<String, dynamic> metadataMap;
    if (metadataJson is String) {
      metadataMap = jsonDecode(metadataJson);
    } else if (metadataJson is Map<String, dynamic>) {
      metadataMap = metadataJson;
    } else {
      debugPrint('TelnyxVoipClient: Invalid metadata format in push payload.');
      return;
    }

    final pushMetaData = PushMetaData.fromJson(metadataMap);

    // Check if this push has already been actioned (accepted or declined).
    final bool isActioned =
        (pushMetaData.isAnswer ?? false) || (pushMetaData.isDecline ?? false);

    if (isActioned) {
      // This is an app launch from an accepted/declined push.
      // Bypass the UI display and go straight to connection handling.
      debugPrint(
          'TelnyxVoipClient: Handling actioned push. Bypassing UI display.');

      // We need to get the stored config to connect.
      final config = await ConfigHelper.getConfig();
      if (config == null) {
        debugPrint(
            'TelnyxVoipClient: No stored config found for push handling. Aborting.');
        return;
      }
      // Update the in-memory config to ensure the session manager uses it.
      _storedConfig = config;

      // This will call the low-level telnyx_webrtc client to connect with the correct state.
      _sessionManager.handlePushNotificationWithConfig(pushMetaData, config);
    } else {
      // This is an initial push notification from a background isolate.
      // Display the native incoming call UI via the gateway.
      debugPrint('TelnyxVoipClient: Handling initial push. Displaying UI.');
      await _pushNotificationManager!.handlePushNotification(payload);
    }
  }

  /// Refreshes the current push token.
  ///
  /// Returns the new token if successful, null otherwise.
  Future<String?> refreshPushToken() async {
    if (_disposed) throw StateError('TelnyxVoipClient has been disposed');

    await _ensurePushNotificationManagerInitialized();
    return await _pushNotificationManager!.refreshToken();
  }

  /// Initializes the internal components.
  void _initializeComponents() {
    // Initialize session manager
    _sessionManager = SessionManager();

    // Create CallKit manager if native UI is enabled (but don't initialize yet)
    if (_pushConfig.enableNativeUI) {
      _callKitManager = CallKitManager(enableNativeUI: true);
    }

    // Initialize call state controller with CallKit manager
    _callStateController = CallStateController(
      _sessionManager.telnyxClient,
      _sessionManager,
      callKitManager: _callKitManager,
    );

    // Set up callbacks for waiting for invite logic
    _callStateController.setWaitingForInviteCallbacks(
      isWaitingForInvite: () => _waitingForInvite,
      onInviteAutoAccepted: () {
        debugPrint(
            'TelnyxVoipClient: Invite auto-accepted from terminated state, resetting waiting flag');
        _waitingForInvite = false;
      },
    );

    // Now initialize CallKit manager with callbacks that can access _callStateController
    if (_callKitManager != null) {
      _callKitManager!.initialize(
        onCallAccepted: (callId) {
          // [PUSH-DIAG] Log CallKit acceptance event
          debugPrint(
              '[PUSH-DIAG] VoipClient: CallKit onCallAccepted fired for $callId');
          debugPrint(
              '[PUSH-DIAG] VoipClient: Current calls count=${currentCalls.length}');

          // [PUSH-DIAG] Check if push data exists in SharedPreferences
          TelnyxClient.getPushData().then((storedData) {
            debugPrint(
                '[PUSH-DIAG] VoipClient: Checking SharedPreferences for existing push data...');
            debugPrint(
                '[PUSH-DIAG] VoipClient: StoredPushData exists=${storedData != null}');
            if (storedData != null) {
              debugPrint(
                  '[PUSH-DIAG] VoipClient: StoredPushData.keys=${storedData.keys.toList()}');
              debugPrint('[PUSH-DIAG] VoipClient: StoredPushData=$storedData');
            }
          });

          // Handle foreground call acceptance directly
          final call = _callStateController.currentCalls
              .where((c) => c.callId == callId)
              .firstOrNull;

          debugPrint(
              '[PUSH-DIAG] VoipClient: Found call with matching ID=${call != null}');
          if (call != null) {
            debugPrint(
                '[PUSH-DIAG] VoipClient: Call is incoming=${call.isIncoming}');
            debugPrint(
                '[PUSH-DIAG] VoipClient: Call state=${call.currentState}');
            debugPrint(
                '[PUSH-DIAG] VoipClient: Can answer=${call.currentState.canAnswer}');
          }
          debugPrint(
              '[PUSH-DIAG] VoipClient: Found answerable call=${call != null && call.isIncoming && call.currentState.canAnswer}');

          if (call != null && call.isIncoming && call.currentState.canAnswer) {
            debugPrint(
                'TelnyxVoipClient: Answering call $callId from foreground');
            call.answer();
          } else {
            debugPrint(
                'TelnyxVoipClient: Call $callId not found or not in answerable state');
          }
        },
        onCallDeclined: (callId) {
          debugPrint('TelnyxVoipClient: Call declined from CallKit - $callId');
          // Handle foreground call decline directly
          final call = _callStateController.currentCalls
              .where((c) => c.callId == callId)
              .firstOrNull;
          if (call != null && call.currentState.canHangup) {
            debugPrint(
                'TelnyxVoipClient: Declining call $callId from foreground');
            call.hangup();
          } else {
            debugPrint(
                'TelnyxVoipClient: Call $callId not found or not in declinable state');
          }
        },
        onCallEnded: (callId) {
          debugPrint('TelnyxVoipClient: Call ended from CallKit - $callId');
          // Update call state if needed
          final call = _callStateController.currentCalls
              .where((c) => c.callId == callId)
              .firstOrNull;
          if (call != null && !call.currentState.isTerminated) {
            call.hangup();
          }
        },
        // NEW: Add push notification callback for terminated state handling
        onPushNotificationAccepted: _handlePushNotificationAccepted,
      );
    }

    // Monitor connection state for call cleanup
    _callStateController
        .monitorConnectionState(_sessionManager.connectionState);
  }

  /// Ensures the push notification manager is initialized.
  Future<void> _ensurePushNotificationManagerInitialized() async {
    if (_pushNotificationManager != null) return;

    _pushNotificationManager = PushNotificationManager(config: _pushConfig);

    await _pushNotificationManager!.initialize(
      onPushNotificationProcessed: _handlePushNotificationProcessed,
      onPushNotificationAccepted: _handlePushNotificationAccepted,
      onPushNotificationDeclined: _handlePushNotificationDeclined,
      onTokenRefresh: _handleTokenRefresh,
      onForegroundCallAccepted: (callId) {
        debugPrint('TelnyxVoipClient: Foreground call accepted - $callId');
        // Handle foreground call acceptance
        final call = _callStateController.currentCalls
            .where((c) => c.callId == callId)
            .firstOrNull;
        if (call != null && call.isIncoming && call.currentState.canAnswer) {
          debugPrint('TelnyxVoipClient: Answering foreground call $callId');
          call.answer();
        } else {
          debugPrint(
              'TelnyxVoipClient: Foreground call $callId not found or not in answerable state');
        }
      },
      onForegroundCallDeclined: (callId) {
        debugPrint('TelnyxVoipClient: Foreground call declined - $callId');
        // Handle foreground call decline
        final call = _callStateController.currentCalls
            .where((c) => c.callId == callId)
            .firstOrNull;
        if (call != null && call.currentState.canHangup) {
          debugPrint('TelnyxVoipClient: Declining foreground call $callId');
          call.hangup();
        } else {
          debugPrint(
              'TelnyxVoipClient: Foreground call $callId not found or not in declinable state');
        }
      },
      onForegroundCallEnded: (callId) {
        debugPrint('TelnyxVoipClient: Foreground call ended - $callId');
        // Handle foreground call end
        final call = _callStateController.currentCalls
            .where((c) => c.callId == callId)
            .firstOrNull;
        if (call != null && !call.currentState.isTerminated) {
          debugPrint('TelnyxVoipClient: Ending foreground call $callId');
          call.hangup();
        }
      },
    );
  }

  /// Handles processed push notifications.
  void _handlePushNotificationProcessed(PushMetaData pushMetaData) {
    // Store the push metadata for potential use later
    _storedPushMetaData = pushMetaData;

    // Connect with push metadata to handle the incoming call
    _sessionManager.connectWithPushMetadata(pushMetaData);
  }

  /// Handles when a push notification is accepted via CallKit.
  ///
  /// This method follows the pattern from the old working implementation:
  /// 1. First check if there's an existing answerable incoming call
  /// 2. If yes, answer it directly (like old txClientViewModel.accept())
  /// 3. If no, fall back to push metadata processing for app launch
  void _handlePushNotificationAccepted(
      String callId, Map<String, dynamic> extra) async {
    // [PUSH-DIAG] Log push notification acceptance
    debugPrint(
        '[PUSH-DIAG] VoipClient: _handlePushNotificationAccepted CALLED');
    debugPrint('[PUSH-DIAG] VoipClient: callId=$callId');
    debugPrint('[PUSH-DIAG] VoipClient: extra.keys=${extra.keys.toList()}');
    debugPrint(
        '[PUSH-DIAG] VoipClient: Platform=${Platform.isIOS ? 'iOS' : 'Android'}');
    debugPrint(
        '[PUSH-DIAG] VoipClient: Current calls count=${currentCalls.length}');
    debugPrint(
        '[PUSH-DIAG] VoipClient: Current waiting for invite flag=$_waitingForInvite');

    debugPrint(
        'TelnyxVoipClient: ==================== PUSH NOTIFICATION ACCEPTED ====================');
    debugPrint('TelnyxVoipClient: Push notification accepted for call $callId');
    debugPrint(
        'TelnyxVoipClient: Platform: ${Platform.isIOS ? 'iOS' : 'Android'}');
    debugPrint('TelnyxVoipClient: Current calls count: ${currentCalls.length}');
    debugPrint(
        'TelnyxVoipClient: Current waiting for invite flag: $_waitingForInvite');

    try {
      if (Platform.isIOS) {
        // iOS-specific logic: Follow the old working implementation pattern
        // Step 1: Check if we have an existing answerable incoming call (like old implementation)
        final existingIncomingCall = currentCalls
            .where((call) => call.isIncoming && call.currentState.canAnswer)
            .firstOrNull;

        if (existingIncomingCall != null) {
          // Path A: We have an existing incoming call - answer it directly
          // This handles the case where the app is backgrounded or connection exists
          debugPrint(
              'TelnyxVoipClient: iOS - Found existing answerable incoming call ${existingIncomingCall.callId}. Answering directly.');
          await existingIncomingCall.answer();
          debugPrint(
              'TelnyxVoipClient: iOS - Successfully answered existing incoming call');
        } else {
          // Path B: No existing call - process as push notification with metadata
          // This handles the case where the app is terminated and needs to launch
          debugPrint(
              'TelnyxVoipClient: iOS - No existing answerable call found. Processing as push notification.');
          final metadata = _extractMetadata(extra);
          debugPrint(
              '[PUSH-DIAG] VoipClient: Metadata extracted=${metadata != null}');
          if (metadata != null) {
            debugPrint(
                '[PUSH-DIAG] VoipClient: Metadata keys=${metadata.keys.toList()}');
            debugPrint(
                'TelnyxVoipClient: iOS - Metadata present. Storing push data with acceptance flag. Metadata: $metadata');

            // Create the correct payload structure that TelnyxClient.setPushMetaData expects
            // The method expects metadata to be a JSON string, not a Map object
            final correctPayload = {
              'metadata':
                  jsonEncode(metadata), // Convert metadata Map to JSON string
            };

            TelnyxClient.setPushMetaData(
              correctPayload,
              isAnswer: true,
              isDecline: false,
            );

            // CRITICAL: Set waiting for invite flag for terminated state auto-acceptance
            // This matches the old working implementation pattern
            _waitingForInvite = true;
            debugPrint(
                'TelnyxVoipClient: iOS - Set waiting for invite flag to true for terminated state acceptance');

            debugPrint(
                'TelnyxVoipClient: iOS - Updated stored push data with acceptance flag');
            debugPrint(
                'TelnyxVoipClient: iOS - Stored payload keys: ${correctPayload.keys.toList()}');
            debugPrint(
                'TelnyxVoipClient: iOS - Stored metadata type: ${correctPayload['metadata'].runtimeType}');

            // CRITICAL: Automatically connect using stored config for terminated state
            // This is the missing piece that makes locked screen calls work
            debugPrint(
                'TelnyxVoipClient: iOS - Attempting automatic connection for terminated state...');
            final config = await ConfigHelper.getConfig();
            if (config != null) {
              debugPrint(
                  'TelnyxVoipClient: iOS - Found stored config, initiating connection...');
              _storedConfig = config;

              // Create push metadata from the extracted metadata
              final pushMetaData = PushMetaData.fromJson(metadata);
              pushMetaData.isAnswer = true;

              // Connect with push metadata to handle the incoming call
              _sessionManager.handlePushNotificationWithConfig(
                  pushMetaData, config);
              debugPrint(
                  'TelnyxVoipClient: iOS - Connection initiated with push metadata');
            } else {
              debugPrint(
                  'TelnyxVoipClient: iOS - WARNING: No stored config found for automatic connection!');
            }
          } else {
            debugPrint(
                'TelnyxVoipClient: iOS - WARNING: No metadata found, cannot process push notification!');
            // Attempt fallback: try to answer any existing call as last resort
            final anyIncomingCall =
                currentCalls.where((call) => call.isIncoming).firstOrNull;
            if (anyIncomingCall != null) {
              debugPrint(
                  'TelnyxVoipClient: iOS - Fallback: attempting to answer any incoming call ${anyIncomingCall.callId}');
              await anyIncomingCall.answer();
            }
          }
        }
      } else {
        // Android logic: Keep the existing approach that works
        // On Android, the extra structure should already be compatible with setPushMetaData
        TelnyxClient.setPushMetaData(
          extra,
          isAnswer: true,
          isDecline: false,
        );

        debugPrint(
            'TelnyxVoipClient: Android - Updated stored push data with acceptance flag (unchanged)');
      }
    } catch (e) {
      debugPrint(
          'TelnyxVoipClient: Error processing push notification acceptance: $e');
    }

    debugPrint('TelnyxVoipClient: Push notification acceptance processed');
    debugPrint(
        'TelnyxVoipClient: Final waiting for invite flag: $_waitingForInvite');
    debugPrint(
        'TelnyxVoipClient: ==================== PUSH ACCEPTANCE COMPLETE ====================');
  }

  /// Handles when a push notification is declined via CallKit.
  void _handlePushNotificationDeclined(
      String callId, Map<String, dynamic> extra) async {
    debugPrint('TelnyxVoipClient: Push notification declined for call $callId');

    final metadata = _extractMetadata(extra);
    if (metadata != null) {
      try {
        final PushMetaData pushMetaData = PushMetaData.fromJson(metadata)
          ..isDecline = true;
        final config = await ConfigHelper.getConfig();

        debugPrint(
            'TelnyxVoipClient: Handling push notification decline via background client.');

        if (config != null) {
          // The SessionManager holds the TelnyxClient instance.
          // We use it to send the decline message.
          _sessionManager.handlePushNotificationWithConfig(
              pushMetaData, config);
        } else {
          debugPrint(
              'TelnyxVoipClient: Could not get config for temp client to decline push');
        }
      } catch (e) {
        debugPrint(
            'TelnyxVoipClient: Error processing push notification decline: $e');
      } finally {
        // Only dispose if this is a background client (created for terminated state)
        // Main app clients should persist for future calls
        if (_isBackgroundClient) {
          debugPrint(
              'TelnyxVoipClient: Disposing background client after decline action.');
          dispose();
        } else {
          debugPrint(
              'TelnyxVoipClient: Keeping main app client alive after decline action.');
        }
      }
    }
  }

  /// Extracts metadata from CallKit extra data.
  Map<String, dynamic>? _extractMetadata(Map<String, dynamic> extra) {
    try {
      // First, try to get metadata from the standard location
      var metadata = extra['metadata'];

      // On iOS, the push notification payload includes an 'aps' wrapper
      // So if metadata is not found at extra['metadata'], check if it exists
      // at the root level alongside 'aps'
      if (metadata == null && extra.containsKey('aps')) {
        // This is likely an iOS push notification with aps wrapper
        // Look for metadata at the root level
        final extraKeys = extra.keys.where((key) => key != 'aps').toList();
        if (extraKeys.contains('metadata')) {
          metadata = extra['metadata'];
        }
      }

      if (metadata == null) return null;

      if (metadata is String) {
        return jsonDecode(metadata) as Map<String, dynamic>;
      } else if (metadata is Map<String, dynamic>) {
        return metadata;
      } else if (metadata is Map) {
        // Handle case where metadata is Map but not the exact type (common on iOS)
        return Map<String, dynamic>.from(metadata);
      }
      return null;
    } catch (e) {
      debugPrint('TelnyxVoipClient: Error extracting metadata: $e');
      return null;
    }
  }

  /// Handles push token refresh.
  void _handleTokenRefresh(String newToken) {
    debugPrint(
        'TelnyxVoipClient: Push token refreshed: ${newToken.substring(0, 10)}...');
    // Here you could implement token registration with your backend
  }

  /// Disposes of the client and cleans up all resources.
  ///
  /// This method should be called when the client is no longer needed
  /// to prevent memory leaks and ensure proper cleanup.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _callStateController.dispose();
    _sessionManager.dispose();
    _pushNotificationManager?.dispose();
    _callKitManager?.dispose();

    // Clear stored data
    _storedConfig = null;
    _storedPushMetaData = null;
    _storedPushPayload = null;
    _waitingForInvite = false;
  }
}
