import 'package:telnyx_webrtc/config/telnyx_config.dart';

class Profile {
  final bool isTokenLogin;
  final String token;
  final String sipUser;
  final String sipPassword;
  final String sipCallerIDName;
  final String sipCallerIDNumber;

  Profile({
    required this.isTokenLogin,
    this.token = '',
    this.sipUser = '',
    this.sipPassword = '',
    this.sipCallerIDName = '',
    this.sipCallerIDNumber = '',
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      isTokenLogin: json['isTokenLogin'] as bool,
      token: json['token'] as String? ?? '',
      sipUser: json['sipUser'] as String? ?? '',
      sipPassword: json['sipPassword'] as String? ?? '',
      sipCallerIDName: json['sipCallerIDName'] as String? ?? '',
      sipCallerIDNumber: json['sipCallerIDNumber'] as String? ?? '',
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
    };
  }

  Config toTelnyxConfig() {
    if (isTokenLogin) {
      return TokenConfig(
        sipToken: token,
        sipCallerIDName: sipCallerIDName,
        sipCallerIDNumber: sipCallerIDNumber,
        debug: false,
      );
    } else {
      return CredentialConfig(
        sipUser: sipUser,
        sipPassword: sipPassword,
        sipCallerIDName: sipCallerIDName,
        sipCallerIDNumber: sipCallerIDNumber,
        debug: false,
      );
    }
  }
}