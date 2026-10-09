import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/service/diagnostics_log_service.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/diagnostics/diagnostics_common.dart';
import 'package:telnyx_webrtc/utils/logging/log_collector.dart';

/// Structured SDK logs captured by [DiagnosticsLogService].
///
/// [LogCollector] is poll-only — it exposes no stream or notifier — so this
/// panel reads on open and on an explicit refresh rather than updating live.
class LogsPanel extends StatefulWidget {
  /// Creates the logs panel.
  const LogsPanel({super.key});

  @override
  State<LogsPanel> createState() => _LogsPanelState();
}

class _LogsPanelState extends State<LogsPanel> {
  List<LogEntry> _entries = const [];
  bool _wasStolen = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final service = DiagnosticsLogService.instance;
    // Note the pre-refresh state: if another component took the global slot,
    // say so instead of showing a frozen buffer as if it were current.
    final stolen = service.collector != null && !service.isActiveGlobally;
    service.ensureInstalled();
    setState(() {
      _wasStolen = stolen;
      // Newest first for reading.
      _entries = service.getLogs().reversed.toList();
    });
  }

  void _clear() {
    DiagnosticsLogService.instance.clear();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiagnosticsSectionHeader(
          title: 'Logs',
          subtitle: '${_entries.length} entries · newest first',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const ValueKey('diagnostics_logs_refresh'),
                icon: const Icon(Icons.refresh, size: fontSizeL),
                tooltip: 'Refresh',
                onPressed: _refresh,
              ),
              IconButton(
                key: const ValueKey('diagnostics_logs_clear'),
                icon: const Icon(Icons.delete_outline, size: fontSizeL),
                tooltip: 'Clear',
                onPressed: _entries.isEmpty ? null : _clear,
              ),
            ],
          ),
        ),
        if (_wasStolen)
          const DiagnosticsUnavailableTile(
            title: 'Log capture was interrupted',
            reason:
                'Another component claimed the SDK global log collector, so '
                'entries were missed. Capture has been re-claimed.',
          ),
        if (_entries.isEmpty)
          const DiagnosticsEmptyState(message: 'No log entries captured yet.')
        else
          ..._entries.take(200).map((e) => LogEntryTile(entry: e)),
        if (_entries.length > 200)
          Padding(
            padding: const EdgeInsets.only(top: spacingS),
            child: Text(
              'Showing the newest 200 of ${_entries.length}.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

/// A single [LogEntry] rendered as a row.
class LogEntryTile extends StatelessWidget {
  /// Creates a log entry tile.
  const LogEntryTile({required this.entry, super.key});

  /// The entry to render.
  final LogEntry entry;

  Color get _levelColor {
    switch (entry.level) {
      case 'error':
        return Colors.red.shade700;
      case 'warn':
        return Colors.orange.shade800;
      case 'info':
        return active_text_field_color;
      default:
        return telnyx_grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Timestamps are ISO-8601 UTC; show just the wall clock portion.
    final time = entry.timestamp.length >= 19
        ? entry.timestamp.substring(11, 19)
        : entry.timestamp;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: spacingXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              time,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: spacingS, top: spacingXXS),
            padding: const EdgeInsets.symmetric(
              horizontal: spacingXS,
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: _levelColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(spacingXS),
            ),
            child: Text(
              entry.level.toUpperCase(),
              style: TextStyle(
                fontSize: fontSizeXS + 2,
                fontWeight: FontWeight.bold,
                color: _levelColor,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.message,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: telnyx_soft_black),
                ),
                if (entry.context != null && entry.context!.isNotEmpty)
                  Text(
                    entry.context.toString(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
