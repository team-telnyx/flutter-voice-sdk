import 'package:uuid/uuid.dart';

class StatsMessage {
  final String type;
  final String reportId;
  final int debugReportVersion;
  final String id;
  final String jsonrpc;
  final Map<String, dynamic>? reportData;

  StatsMessage({
    required this.type,
    required this.reportId,
    this.reportData,
    this.debugReportVersion = 1,
    String? id,
    this.jsonrpc = '2.0',
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'jsonrpc': jsonrpc,
      'id': id,
      'type': type,
      'debug_report_id': reportId,
      'debug_report_version': debugReportVersion,
      'debug_report_data': reportData,
    };
  }
}

class DebugReportStartMessage extends StatsMessage {
  DebugReportStartMessage({required super.reportId})
      : super(
          type: 'debug_report_start',
        );
}

class DebugReportStopMessage extends StatsMessage {
  DebugReportStopMessage({required super.reportId})
      : super(
          type: 'debug_report_stop',
        );
}

class DebugReportDataMessage extends StatsMessage {
  DebugReportDataMessage({
    required super.reportId,
    required Map<String, dynamic> super.reportData,
  }) : super(
          type: 'debug_report_data',
        );

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['debug_report_data'] = reportData;
    return json;
  }
}