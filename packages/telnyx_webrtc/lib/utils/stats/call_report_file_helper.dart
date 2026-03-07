import 'dart:io';
import 'package:path_provider/path_provider.dart' as path_provider;

/// Save call report JSON to local file on mobile platforms.
/// Returns the file path if successful, null otherwise.
Future<String?> saveCallReportToFile(String callId, String jsonPayload) async {
  try {
    final tempDir = await path_provider.getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/call_stats');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/call_stats_$callId.json');
    await file.writeAsString(jsonPayload);
    return file.path;
  } catch (_) {
    return null;
  }
}
