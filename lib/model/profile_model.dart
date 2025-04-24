import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:telnyx_flutter_webrtc/firebase_options.dart';
import 'package:telnyx_flutter_webrtc/utils/custom_sdk_logger.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

class Profile {
  final bool isTokenLogin;
  final String token;
  final String sipUser;
  final String sipPassword;
  final String sipCallerIDName;
  final String sipCallerIDNumber;
  final String? notificationToken;

  Profile({
    required this.isTokenLogin,
    this.token = '',
    this.sipUser = '',
    this.sipPassword = '',
    this.sipCallerIDName = '',
    this.sipCallerIDNumber = '',
    this.notificationToken = '',
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      isTokenLogin: json['isTokenLogin'] as bool,
      token: json['token'] as String? ?? '',
      sipUser: json['sipUser'] as String? ?? '',
      sipPassword: json['sipPassword'] as String? ?? '',
      sipCallerIDName: json['sipCallerIDName'] as String? ?? '',
      sipCallerIDNumber: json['sipCallerIDNumber'] as String? ?? '',
      notificationToken: json['notificationToken'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isTokenLogin': isTokenLogin,
      'token': token,
      'sipUser': sipUser,
      'sipPassword': sipPassword,
      'sipCallerIDName': sipCallerIDName,
      'sipCallerIDNumber': sipCallerIDNumber,
      'notificationToken': notificationToken,
    };
  }

  Future<String?> getNotificationTokenForPlatform() async {
    var token;

    if (kIsWeb) {
      return null;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // If no apps are initialized, initialize one now.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: kIsWeb ? DefaultFirebaseOptions.currentPlatform : null,
        );
      }
      token = (await FirebaseMessaging.instance.getToken())!;
    } else if (Platform.isIOS) {
      token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
    }
    return token;
  }

  Future<Config> toTelnyxConfig() async {
    if (isTokenLogin) {
      return TokenConfig(
          sipToken: token,
          sipCallerIDName: sipCallerIDName,
          sipCallerIDNumber: sipCallerIDNumber,
          notificationToken: await getNotificationTokenForPlatform() ?? '',
          debug: false,
          logLevel: LogLevel.all,
          customLogger: CustomSDKLogger(),);
    } else {
      return CredentialConfig(
        sipUser: sipUser,
        sipPassword: sipPassword,
        sipCallerIDName: sipCallerIDName,
        sipCallerIDNumber: sipCallerIDNumber,
        notificationToken: await getNotificationTokenForPlatform() ?? '',
        debug: false,
        logLevel: LogLevel.all,
        customLogger: CustomSDKLogger(),
      );
    }
  }
}
