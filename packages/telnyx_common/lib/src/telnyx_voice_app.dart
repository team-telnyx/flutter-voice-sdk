import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_common/src/telnyx_voip_client.dart';
import 'package:telnyx_common/src/models/connection_state.dart' as telnyx;

/// A comprehensive wrapper widget that handles all Telnyx SDK lifecycle management.
///
/// This widget automatically handles:
/// - Push notification initialization from terminated state
/// - Background/foreground lifecycle detection and auto-reconnection
/// - Login state management with automatic reconnection
/// - CallKit integration preparation
///
/// Simply wrap your main app widget with this to get full Telnyx functionality:
/// ```dart
/// TelnyxVoiceApp(
///   voipClient: myVoipClient,
///   child: MyApp(),
/// )
/// ```
class TelnyxVoiceApp extends StatefulWidget {
  /// The TelnyxVoipClient instance to manage
  final TelnyxVoipClient voipClient;
  
  /// The child widget (typically your main app)
  final Widget child;
  
  /// Optional callback when push notification processing starts
  final VoidCallback? onPushNotificationProcessingStarted;
  
  /// Optional callback when push notification processing completes
  final VoidCallback? onPushNotificationProcessingCompleted;
  
  /// Optional callback for additional background/foreground handling
  final void Function(AppLifecycleState state)? onAppLifecycleStateChanged;
  
  /// Whether to enable automatic login/reconnection (default: true)
  final bool enableAutoReconnect;
  
  /// Whether to skip web platform for background detection (default: true)
  final bool skipWebBackgroundDetection;

  const TelnyxVoiceApp({
    super.key,
    required this.voipClient,
    required this.child,
    this.onPushNotificationProcessingStarted,
    this.onPushNotificationProcessingCompleted,
    this.onAppLifecycleStateChanged,
    this.enableAutoReconnect = true,
    this.skipWebBackgroundDetection = true,
  });

  @override
  State<TelnyxVoiceApp> createState() => _TelnyxVoiceAppState();
}

class _TelnyxVoiceAppState extends State<TelnyxVoiceApp> with WidgetsBindingObserver {
  bool _processingPushOnLaunch = false;
  bool _backgroundDetectorIgnore = false;
  
  // Track current connection state
  telnyx.ConnectionState _currentConnectionState = const telnyx.Disconnected();
  StreamSubscription<telnyx.ConnectionState>? _connectionStateSubscription;

  @override
  void initState() {
    super.initState();
    
    // Add lifecycle observer for background detection
    if (!widget.skipWebBackgroundDetection || !kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
    }
    
    // Listen to connection state changes
    _connectionStateSubscription = widget.voipClient.connectionState.listen((state) {
      _currentConnectionState = state;
    });
    
    // Handle initial push notification if app was launched from terminated state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForInitialPushNotification();
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    if (!widget.skipWebBackgroundDetection || !kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Store the last state for reference
    
    // Call optional user callback first
    widget.onAppLifecycleStateChanged?.call(state);
    
    // Handle auto-reconnection logic
    if (widget.enableAutoReconnect) {
      _handleAppLifecycleStateChange(state);
    }
  }

  /// Handle app lifecycle changes for auto-reconnection
  void _handleAppLifecycleStateChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        // App going to background - disconnect
        _handleAppBackgrounded();
        break;
      case AppLifecycleState.hidden:
        // New state in Flutter 3.13+
        break;
    }
  }

  /// Handle app going to background - disconnect like the old implementation
  void _handleAppBackgrounded() async {
    if (kDebugMode) {
      print('[TelnyxVoiceApp] App backgrounded - disconnecting (matching old BackgroundDetector behavior)');
    }
    
    try {
      // Always disconnect when backgrounded (matches old implementation)
      await widget.voipClient.logout();
      
      if (kDebugMode) {
        print('[TelnyxVoiceApp] Successfully disconnected on background');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[TelnyxVoiceApp] Error disconnecting on background: $e');
      }
    }
  }

  /// Handle app resuming from background
  void _handleAppResumed() async {
    if (kDebugMode) {
      print('[TelnyxVoiceApp] App resumed - checking reconnection needs');
    }
    
    // If we're ignoring (e.g., from push call), don't auto-reconnect
    if (_backgroundDetectorIgnore) {
      if (kDebugMode) {
        print('[TelnyxVoiceApp] Background detector ignore flag set - skipping reconnection');
      }
      return;
    }

    // Check current connection state and reconnect if needed
    final currentConnectionState = _currentConnectionState;
    
    if (kDebugMode) {
      print('[TelnyxVoiceApp] Current connection state: $currentConnectionState');
    }
    
    // If we're not connected and have stored credentials, attempt reconnection
    if (currentConnectionState is! telnyx.Connected) {
      await _attemptAutoReconnection();
    }
  }

  /// Attempt to reconnect using stored credentials
  Future<void> _attemptAutoReconnection() async {
    try {
      if (kDebugMode) {
        print('[TelnyxVoiceApp] Attempting auto-reconnection...');
      }
      
      // Try to get stored config and reconnect
      // This uses the same logic as the old implementation
      final success = await widget.voipClient.loginFromStoredConfig();
      
      if (kDebugMode) {
        print('[TelnyxVoiceApp] Auto-reconnection ${success ? 'successful' : 'failed'}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[TelnyxVoiceApp] Auto-reconnection error: $e');
      }
    }
  }

  /// Check for initial push notification when app launches
  Future<void> _checkForInitialPushNotification() async {
    if (_processingPushOnLaunch) return;
    
    _processingPushOnLaunch = true;
    widget.onPushNotificationProcessingStarted?.call();
    
    try {
      Map<String, dynamic>? pushData;
      
      // Try Firebase first (Android)
      if (!kIsWeb && Platform.isAndroid) {
        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          if (kDebugMode) {
            print('[TelnyxVoiceApp] Found initial Firebase message: ${initialMessage.data}');
          }
          pushData = _convertFirebaseMessageToPushData(initialMessage);
        }
      }
      
      // Fallback to TelnyxClient.getPushData() for iOS or if Firebase didn't have data
      if (pushData == null) {
        final storedPushData = await TelnyxClient.getPushData();
        if (storedPushData != null && storedPushData.isNotEmpty) {
          if (kDebugMode) {
            print('[TelnyxVoiceApp] Found stored push data: $storedPushData');
          }
          pushData = storedPushData;
        }
      }
      
      // Process the push notification if found
      if (pushData != null) {
        if (kDebugMode) {
          print('[TelnyxVoiceApp] Processing initial push notification...');
        }
        
        // Set the ignore flag to prevent auto-reconnection during push call
        _setBackgroundDetectorIgnore(true);
        
        // Handle the push notification
        await widget.voipClient.handlePushNotification(pushData);
        
        if (kDebugMode) {
          print('[TelnyxVoiceApp] Initial push notification processed');
        }
      } else {
        if (kDebugMode) {
          print('[TelnyxVoiceApp] No initial push data found');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[TelnyxVoiceApp] Error processing initial push notification: $e');
      }
    } finally {
      _processingPushOnLaunch = false;
      widget.onPushNotificationProcessingCompleted?.call();
    }
  }

  /// Convert Firebase RemoteMessage to push data format
  Map<String, dynamic> _convertFirebaseMessageToPushData(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    
    // Ensure metadata is properly formatted
    if (data['metadata'] is String) {
      try {
        data['metadata'] = jsonDecode(data['metadata']);
      } catch (e) {
        if (kDebugMode) {
          print('[TelnyxVoiceApp] Failed to parse metadata JSON: $e');
        }
      }
    }
    
    return data;
  }

  /// Set the background detector ignore flag (exposed for call handling)
  void _setBackgroundDetectorIgnore(bool ignore) {
    _backgroundDetectorIgnore = ignore;
    if (kDebugMode) {
      print('[TelnyxVoiceApp] Background detector ignore set to: $ignore');
    }
  }

  /// Public method to reset background detector ignore (for call end cleanup)
  void resetBackgroundDetectorIgnore() {
    _setBackgroundDetectorIgnore(false);
  }

  @override
  Widget build(BuildContext context) {
    // Simply return the child - all lifecycle management is handled internally
    return widget.child;
  }
} 