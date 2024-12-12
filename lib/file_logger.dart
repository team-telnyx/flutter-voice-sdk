import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileLogger {
  static FileLogger? _instance;
  late File _logFile;

  FileLogger._();

  /// Singleton pattern to ensure only one instance of FileLogger
  static Future<FileLogger> getInstance() async {
    if (_instance == null) {
      _instance = FileLogger._();
      await _instance!._initializeLogFile();
    }
    return _instance!;
  }

  /// Initialize the log file in the app's documents directory
  Future<void> _initializeLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    _logFile = File('${directory.path}/logs.txt');

    // Create the file if it doesn't exist
    if (!(await _logFile.exists())) {
      await _logFile.create();
    }
  }

  /// Write a log entry to the file
  Future<void> writeLog(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    await _logFile.writeAsString('$timestamp: $message\n\n',
        mode: FileMode.append,);
  }

  /// Export the log file for sharing
  Future<String> exportLogs() async {
    try {
      if (await _logFile.exists()) {
        // Read and return the contents of the log file
        final logs = await _logFile.readAsString();
        await clearLogs();
        return logs;
      } else {
        throw Exception('Log file does not exist.');
      }
    } catch (e) {
      // Return an error message if something goes wrong
      return 'Error reading log file: $e';
    }
  }

  /// Clear the log file
  Future<void> clearLogs() async {
    if (await _logFile.exists()) {
      await _logFile.writeAsString('');
    }
  }
}
