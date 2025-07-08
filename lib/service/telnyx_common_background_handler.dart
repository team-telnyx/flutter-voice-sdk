import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_flutter_webrtc/service/telnyx_common_push_service.dart';

final logger = Logger();

/// Background message handler for telnyx_common integration.
/// 
/// This function is called when a push notification is received while the app
/// is in the background or terminated. It uses telnyx_common for handling
/// the notification.
@pragma('vm:entry-point')
Future<void> telnyxCommonBackgroundMessageHandler(RemoteMessage message) async {
  logger.i('TelnyxCommon background message handler called: ${message.data}');
  
  try {
    // Handle the background message using telnyx_common
    await TelnyxCommonPushService.handleBackgroundMessage(message);
    
    logger.i('Background message handled successfully');
  } catch (e) {
    logger.e('Failed to handle background message: $e');
  }
}