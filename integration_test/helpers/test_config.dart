/// Test configuration and environment variables
class TestConfig {
  // Credentials from environment
  static const sipUsername = String.fromEnvironment(
    'APP_LOGIN_USER',
    defaultValue: '',
  );
  static const sipPassword = String.fromEnvironment(
    'APP_LOGIN_PASSWORD',
    defaultValue: '',
  );
  static const sipCallerNumber = String.fromEnvironment(
    'APP_LOGIN_NUMBER',
    defaultValue: '',
  );

  // Token-based login (optional - for token tests)
  static const tokenCredential = String.fromEnvironment(
    'APP_LOGIN_TOKEN',
    defaultValue: '',
  );

  // Test destinations
  static const testDestinationEcho = '18004377950'; // Telnyx echo test
  static const testDestinationSip = String.fromEnvironment(
    'TEST_DESTINATION_SIP',
    defaultValue: '',
  );

  // Timeouts - generous to avoid flakiness
  static const connectionTimeout = Duration(seconds: 30);
  static const callEstablishTimeout = Duration(seconds: 20);
  static const uiSettleTimeout = Duration(seconds: 5);
  static const shortDelay = Duration(milliseconds: 500);

  // Retry configuration
  static const maxRetries = 3;
  static const retryDelay = Duration(milliseconds: 500);

  // Validation
  static bool get hasSipCredentials =>
      sipUsername.isNotEmpty && sipPassword.isNotEmpty;

  static bool get hasTokenCredentials => tokenCredential.isNotEmpty;
}
