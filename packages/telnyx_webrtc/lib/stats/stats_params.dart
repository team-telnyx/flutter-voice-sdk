import 'package:uuid/uuid.dart';

class StatParams {
  final String type;
  final String debugReportId;
  final Map<String, dynamic> reportData;
  final int debugReportVersion;
  final String id;
  final String jsonrpc;

  StatParams({
    this.type = "debug_report_data",
    required this.debugReportId,
    required this.reportData,
    this.debugReportVersion = 1,
    String? id,
    this.jsonrpc = "2.0",
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      "type": type,
      "debug_report_id": debugReportId,
      "debug_report_data": reportData,
      "debug_report_version": debugReportVersion,
      "id": id,
      "jsonrpc": jsonrpc,
    };
  }
}

class InitiateOrStopStatParams {
  final String type;
  final String debugReportId;
  final int debugReportVersion;
  final String id;
  final String jsonrpc;

  InitiateOrStopStatParams({
    required this.type,
    required this.debugReportId,
    this.debugReportVersion = 1,
    String? id,
    this.jsonrpc = "2.0",
  }) : id = id ?? Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      "type": type,
      "debug_report_id": debugReportId,
      "debug_report_version": debugReportVersion,
      "id": id,
      "jsonrpc": jsonrpc,
    };
  }
}
