import 'package:telnyx_webrtc/model/audio_codec.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/call.dart';

/// Example demonstrating how to use preferred codecs with the Telnyx WebRTC SDK
void main() {
  // Create a TelnyxClient instance
  final client = TelnyxClient();

  // Get the list of supported audio codecs
  final supportedCodecs = client.getSupportedAudioCodecs();
  print('Supported codecs:');
  for (final codec in supportedCodecs) {
    print('  - ${codec.mimeType} @ ${codec.clockRate}Hz, ${codec.channels} channel(s)');
  }

  // Example 1: Making a call with preferred codecs
  void makeCallWithPreferredCodecs() {
    // Define your preferred codecs in order of preference
    final preferredCodecs = [
      // First preference: Opus for high quality
      const AudioCodec(
        mimeType: 'audio/opus',
        clockRate: 48000,
        channels: 2,
        sdpFmtpLine: 'minptime=10;useinbandfec=1',
      ),
      // Second preference: G722 for good quality
      const AudioCodec(
        mimeType: 'audio/G722',
        clockRate: 8000,
        channels: 1,
      ),
      // Third preference: PCMU as fallback
      const AudioCodec(
        mimeType: 'audio/PCMU',
        clockRate: 8000,
        channels: 1,
      ),
    ];

    // Create a new call with preferred codecs
    final call = client.newInvite(
      'John Doe',           // callerName
      '+1234567890',        // callerNumber
      '+0987654321',        // destinationNumber
      'example-state',      // clientState
      preferredCodecs: preferredCodecs,
      debug: true,
    );

    print('Call created with ID: ${call.callId}');
    print('Preferred codecs: ${preferredCodecs.map((c) => c.mimeType).join(', ')}');
  }

  // Example 2: Accepting a call with preferred codecs
  void acceptCallWithPreferredCodecs(/* IncomingInviteParams invite */) {
    // Define preferred codecs for accepting calls
    final preferredCodecs = [
      // Prefer G722 for incoming calls
      const AudioCodec(
        mimeType: 'audio/G722',
        clockRate: 8000,
        channels: 1,
      ),
      // Fallback to PCMU
      const AudioCodec(
        mimeType: 'audio/PCMU',
        clockRate: 8000,
        channels: 1,
      ),
    ];

    // Note: In a real application, you would get the invite parameter
    // from the onSocketMessageReceived callback
    /*
    final call = client.acceptCall(
      invite,
      'Jane Doe',           // callerName
      '+1234567890',        // callerNumber
      'example-state',      // clientState
      preferredCodecs: preferredCodecs,
      debug: true,
    );
    */

    print('Would accept call with preferred codecs: ${preferredCodecs.map((c) => c.mimeType).join(', ')}');
  }

  // Example 3: Using Call class methods directly
  void useCallClassMethods() {
    // Create a call instance
    final call = Call(client);

    // Define preferred codecs
    final preferredCodecs = [
      const AudioCodec(
        mimeType: 'audio/opus',
        clockRate: 48000,
        channels: 2,
        sdpFmtpLine: 'minptime=10;useinbandfec=1',
      ),
    ];

    // Make a call using the Call class method
    call.newInvite(
      'Alice Smith',        // callerName
      '+1111111111',        // callerNumber
      '+2222222222',        // destinationNumber
      'call-state',         // clientState
      preferredCodecs: preferredCodecs,
      debug: true,
    );

    print('Call initiated using Call class with preferred codecs');
  }

  // Example 4: Custom codec configuration
  void customCodecConfiguration() {
    // Create a custom codec configuration
    final customCodec = const AudioCodec(
      mimeType: 'audio/opus',
      clockRate: 48000,
      channels: 1, // Mono instead of stereo
      sdpFmtpLine: 'minptime=20;useinbandfec=0', // Custom parameters
    );

    final preferredCodecs = [customCodec];

    print('Custom codec configuration:');
    print('  MIME Type: ${customCodec.mimeType}');
    print('  Clock Rate: ${customCodec.clockRate}Hz');
    print('  Channels: ${customCodec.channels}');
    print('  SDP FMTP: ${customCodec.sdpFmtpLine}');

    // Use the custom codec in a call
    final call = client.newInvite(
      'Custom User',
      '+3333333333',
      '+4444444444',
      'custom-state',
      preferredCodecs: preferredCodecs,
    );

    print('Call created with custom codec configuration');
  }

  // Run examples
  print('\n=== Example 1: Making a call with preferred codecs ===');
  makeCallWithPreferredCodecs();

  print('\n=== Example 2: Accepting a call with preferred codecs ===');
  acceptCallWithPreferredCodecs();

  print('\n=== Example 3: Using Call class methods ===');
  useCallClassMethods();

  print('\n=== Example 4: Custom codec configuration ===');
  customCodecConfiguration();
}