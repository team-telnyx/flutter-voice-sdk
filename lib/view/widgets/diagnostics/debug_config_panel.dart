import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/diagnostics/diagnostics_common.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';

/// The debug fields on the [Config] the client connected with.
///
/// Read-only: these are `final` on [Config] and only take effect at connect
/// time, so editing them here would be misleading. Change them in the profile
/// and reconnect.
class DebugConfigPanel extends StatelessWidget {
  /// Creates the debug config panel.
  const DebugConfigPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TelnyxClientViewModel>(
      builder: (context, viewModel, child) {
        final config = viewModel.activeConfig;
        if (config == null) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DiagnosticsSectionHeader(
                title: 'Debug config',
                subtitle: 'From the active connection',
              ),
              DiagnosticsEmptyState(
                message: 'Not connected.\nConnect to see the active config.',
              ),
            ],
          );
        }
        return DebugConfigContent(config: config);
      },
    );
  }
}

/// Renders the debug fields of a resolved [Config].
class DebugConfigContent extends StatelessWidget {
  /// Creates the config content.
  const DebugConfigContent({required this.config, super.key});

  /// The config to display.
  final Config config;

  @override
  Widget build(BuildContext context) {
    final reportOptions = CallReportOptions.fromConfig(config);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DiagnosticsSectionHeader(
          title: 'Debug config',
          subtitle: 'From the active connection · read-only',
        ),
        DiagnosticsKeyValueRow(
          label: 'enableCallReports',
          value: '${config.enableCallReports}',
          monospace: true,
        ),
        DiagnosticsKeyValueRow(
          label: 'debugOutput',
          value: config.debugOutput.name,
          monospace: true,
        ),
        DiagnosticsKeyValueRow(
          label: 'debugLogLevel',
          value: config.debugLogLevel.name,
          monospace: true,
        ),
        DiagnosticsKeyValueRow(
          label: 'debugLogMaxEntries',
          value: '${config.debugLogMaxEntries}',
          monospace: true,
        ),
        DiagnosticsKeyValueRow(
          label: 'callReportFlushInterval',
          value: '${config.callReportFlushInterval} ms',
          monospace: true,
        ),
        DiagnosticsKeyValueRow(
          label: 'prefetchIceCandidates',
          value: '${config.prefetchIceCandidates}',
          monospace: true,
        ),
        DiagnosticsKeyValueRow(
          label: 'autoRecoverCalls',
          value: '${config.autoRecoverCalls}',
          monospace: true,
        ),
        DiagnosticsKeyValueRow(
          label: 'hangupOnBeforeUnload',
          value: '${config.hangupOnBeforeUnload}',
          monospace: true,
        ),
        DiagnosticsKeyValueRow(
          label: 'maxReconnectAttempts',
          value: config.maxReconnectAttempts == 0
              ? 'unlimited'
              : '${config.maxReconnectAttempts}',
          monospace: true,
        ),
        const Divider(height: spacingXL),
        Text(
          'Resolved CallReportOptions',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: spacingXS),
        DiagnosticsKeyValueRow(
          label: 'enabled',
          value: '${reportOptions.enabled}',
          monospace: true,
        ),
        DiagnosticsKeyValueRow(
          label: 'outputMode',
          value: reportOptions.outputMode.name,
          monospace: true,
        ),
        DiagnosticsKeyValueRow(
          label: 'flushIntervalMs',
          value: '${reportOptions.flushIntervalMs} ms',
          monospace: true,
        ),
        DiagnosticsKeyValueRow(
          label: 'intervalMs',
          value: '${reportOptions.intervalMs} ms',
          monospace: true,
        ),
        // CallReportOptions.fromConfig maps only enabled/outputMode/
        // flushIntervalMs. config.callReportInterval is dropped on the floor,
        // so intervalMs above is the hardcoded default regardless of config.
        // Flagging it beats rendering a number that looks configured.
        if (reportOptions.intervalMs != config.callReportInterval)
          Padding(
            padding: const EdgeInsets.only(top: spacingS),
            child: DiagnosticsUnavailableTile(
              title: 'intervalMs does not follow config',
              reason:
                  'config.callReportInterval is '
                  '${config.callReportInterval} ms, but '
                  'CallReportOptions.fromConfig does not map it, so the '
                  'collector uses ${reportOptions.intervalMs} ms.',
            ),
          ),
      ],
    );
  }
}
