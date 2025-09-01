import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/region.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_webrtc/utils/logging/custom_logger.dart';

// Mock custom logger for testing
class MockCustomLogger implements CustomLogger {
  @override
  void setLogLevel(LogLevel level) {
    // Mock implementation
  }

  @override
  void log(LogLevel level, String message) {
    // Mock implementation
  }
}

void main() {
  group('Config', () {
    test('should create Config with required parameters', () {
      final config = Config(
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        debug: true,
      );

      expect(config.sipCallerIDName, equals('Test User'));
      expect(config.sipCallerIDNumber, equals('+1234567890'));
      expect(config.debug, isTrue);
      expect(config.logLevel, equals(LogLevel.all));
      expect(config.region, equals(Region.auto));
      expect(config.fallbackOnRegionFailure, isTrue);
      expect(config.forceRelayCandidate, isFalse);
      expect(config.notificationToken, isNull);
      expect(config.autoReconnect, isNull);
      expect(config.customLogger, isNull);
      expect(config.ringTonePath, isNull);
      expect(config.ringbackPath, isNull);
      expect(config.reconnectionTimeout, isNull);
    });

    test('should create Config with all optional parameters', () {
      final customLogger = MockCustomLogger();
      final config = Config(
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        debug: false,
        notificationToken: 'test_token_123',
        autoReconnect: true,
        logLevel: LogLevel.error,
        customLogger: customLogger,
        ringTonePath: '/path/to/ringtone.mp3',
        ringbackPath: '/path/to/ringback.mp3',
        reconnectionTimeout: 30,
        region: Region.us,
        fallbackOnRegionFailure: false,
        forceRelayCandidate: true,
      );

      expect(config.sipCallerIDName, equals('Test User'));
      expect(config.sipCallerIDNumber, equals('+1234567890'));
      expect(config.debug, isFalse);
      expect(config.notificationToken, equals('test_token_123'));
      expect(config.autoReconnect, isTrue);
      expect(config.logLevel, equals(LogLevel.error));
      expect(config.customLogger, equals(customLogger));
      expect(config.ringTonePath, equals('/path/to/ringtone.mp3'));
      expect(config.ringbackPath, equals('/path/to/ringback.mp3'));
      expect(config.reconnectionTimeout, equals(30));
      expect(config.region, equals(Region.us));
      expect(config.fallbackOnRegionFailure, isFalse);
      expect(config.forceRelayCandidate, isTrue);
    });

    test('should handle different log levels', () {
      final configs = [
        Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+123',
          debug: true,
          logLevel: LogLevel.all,
        ),
        Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+123',
          debug: true,
          logLevel: LogLevel.debug,
        ),
        Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+123',
          debug: true,
          logLevel: LogLevel.info,
        ),
        Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+123',
          debug: true,
          logLevel: LogLevel.warning,
        ),
        Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+123',
          debug: true,
          logLevel: LogLevel.error,
        ),
        Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+123',
          debug: true,
          logLevel: LogLevel.none,
        ),
      ];

      expect(configs[0].logLevel, equals(LogLevel.all));
      expect(configs[1].logLevel, equals(LogLevel.debug));
      expect(configs[2].logLevel, equals(LogLevel.info));
      expect(configs[3].logLevel, equals(LogLevel.warning));
      expect(configs[4].logLevel, equals(LogLevel.error));
      expect(configs[5].logLevel, equals(LogLevel.none));
    });

    test('should handle different regions', () {
      final configs = [
        Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+123',
          debug: true,
          region: Region.auto,
        ),
        Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+123',
          debug: true,
          region: Region.us,
        ),
        Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+123',
          debug: true,
          region: Region.europe,
        ),
        Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+123',
          debug: true,
          region: Region.australia,
        ),
      ];

      expect(configs[0].region, equals(Region.auto));
      expect(configs[1].region, equals(Region.us));
      expect(configs[2].region, equals(Region.europe));
      expect(configs[3].region, equals(Region.australia));
    });
  });

  group('TokenConfig', () {
    test('should create TokenConfig with required parameters', () {
      final config = TokenConfig(
        sipToken: 'test_token_123',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        debug: true,
      );

      expect(config.sipToken, equals('test_token_123'));
      expect(config.sipCallerIDName, equals('Test User'));
      expect(config.sipCallerIDNumber, equals('+1234567890'));
      expect(config.debug, isTrue);
    });

    test('should create TokenConfig with all optional parameters', () {
      final customLogger = MockCustomLogger();
      final config = TokenConfig(
        sipToken: 'test_token_123',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        debug: false,
        notificationToken: 'notification_token',
        autoReconnect: false,
        logLevel: LogLevel.warning,
        customLogger: customLogger,
        ringTonePath: '/ringtone.wav',
        ringbackPath: '/ringback.wav',
        reconnectionTimeout: 45,
        region: Region.europe,
        fallbackOnRegionFailure: true,
        forceRelayCandidate: false,
      );

      expect(config.sipToken, equals('test_token_123'));
      expect(config.sipCallerIDName, equals('Test User'));
      expect(config.sipCallerIDNumber, equals('+1234567890'));
      expect(config.debug, isFalse);
      expect(config.notificationToken, equals('notification_token'));
      expect(config.autoReconnect, isFalse);
      expect(config.logLevel, equals(LogLevel.warning));
      expect(config.customLogger, equals(customLogger));
      expect(config.ringTonePath, equals('/ringtone.wav'));
      expect(config.ringbackPath, equals('/ringback.wav'));
      expect(config.reconnectionTimeout, equals(45));
      expect(config.region, equals(Region.europe));
      expect(config.fallbackOnRegionFailure, isTrue);
      expect(config.forceRelayCandidate, isFalse);
    });
  });

  group('CredentialConfig', () {
    test('should create CredentialConfig with required parameters', () {
      final config = CredentialConfig(
        sipUser: 'test_user',
        sipPassword: 'test_password',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        debug: true,
      );

      expect(config.sipUser, equals('test_user'));
      expect(config.sipPassword, equals('test_password'));
      expect(config.sipCallerIDName, equals('Test User'));
      expect(config.sipCallerIDNumber, equals('+1234567890'));
      expect(config.debug, isTrue);
    });

    test('should create CredentialConfig with all optional parameters', () {
      final customLogger = MockCustomLogger();
      final config = CredentialConfig(
        sipUser: 'test_user',
        sipPassword: 'test_password',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        debug: false,
        notificationToken: 'notification_token',
        autoReconnect: true,
        logLevel: LogLevel.info,
        customLogger: customLogger,
        ringTonePath: '/custom_ringtone.mp3',
        ringbackPath: '/custom_ringback.mp3',
        reconnectionTimeout: 60,
        region: Region.australia,
        fallbackOnRegionFailure: false,
        forceRelayCandidate: true,
      );

      expect(config.sipUser, equals('test_user'));
      expect(config.sipPassword, equals('test_password'));
      expect(config.sipCallerIDName, equals('Test User'));
      expect(config.sipCallerIDNumber, equals('+1234567890'));
      expect(config.debug, isFalse);
      expect(config.notificationToken, equals('notification_token'));
      expect(config.autoReconnect, isTrue);
      expect(config.logLevel, equals(LogLevel.info));
      expect(config.customLogger, equals(customLogger));
      expect(config.ringTonePath, equals('/custom_ringtone.mp3'));
      expect(config.ringbackPath, equals('/custom_ringback.mp3'));
      expect(config.reconnectionTimeout, equals(60));
      expect(config.region, equals(Region.australia));
      expect(config.fallbackOnRegionFailure, isFalse);
      expect(config.forceRelayCandidate, isTrue);
    });
  });
}
