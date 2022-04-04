// Annotation which generates the cat.mocks.dart library and the MockCat class.
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/telnyx_client.dart';

import 'telnyx_client_test.mocks.dart';

@GenerateMocks([TelnyxClient])
void main() {
  // Create mock object.
  var telnyxClient = MockTelnyxClient();
  telnyxClient.
}