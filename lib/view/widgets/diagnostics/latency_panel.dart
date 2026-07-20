import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/service/diagnostics_latency_service.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/diagnostics/diagnostics_common.dart';
import 'package:telnyx_webrtc/model/latency_metrics.dart';

/// Registration and call-setup latency measured by the SDK's LatencyTracker.
///
/// Reads from [DiagnosticsLatencyService] rather than subscribing to the
/// tracker directly. The tracker's stream is broadcast with no replay, so a
/// subscription created when this panel opens misses the registration metrics
/// emitted at connect time — the very numbers you open this panel to see. The
/// service subscribes at app start and retains them.
class LatencyPanel extends StatelessWidget {
  /// Creates the latency panel.
  const LatencyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DiagnosticsLatencyService.instance,
      builder: (context, child) {
        final metrics = DiagnosticsLatencyService.instance.history;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DiagnosticsSectionHeader(
              title: 'Latency',
              subtitle: '${metrics.length} recorded · newest first',
              trailing: IconButton(
                key: const ValueKey('diagnostics_latency_clear'),
                icon: const Icon(Icons.delete_outline, size: fontSizeL),
                tooltip: 'Clear',
                onPressed: metrics.isEmpty
                    ? null
                    : DiagnosticsLatencyService.instance.clear,
              ),
            ),
            if (metrics.isEmpty)
              const DiagnosticsEmptyState(
                message:
                    'No metrics yet.\nConnect, or place a call, to record timings.',
              )
            else
              ...metrics.map((m) => LatencyMetricsCard(metrics: m)),
          ],
        );
      },
    );
  }
}

/// One emitted [LatencyMetrics] rendered as a card.
class LatencyMetricsCard extends StatelessWidget {
  /// Creates a card for a single metrics emission.
  const LatencyMetricsCard({required this.metrics, super.key});

  /// The metrics to render.
  final LatencyMetrics metrics;

  /// Mirrors the SDK's own choice of banner in [LatencyMetrics.toString].
  String get _title {
    final isRegistration =
        metrics.callId == null && metrics.registrationLatencyMs != null;
    if (isRegistration) {
      return 'Registration';
    }
    return metrics.isOutbound ? 'Outbound call' : 'Inbound call';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <DiagnosticsKeyValueRow>[
      if (metrics.registrationLatencyMs != null)
        DiagnosticsKeyValueRow(
          label: 'Registration latency',
          value: '${metrics.registrationLatencyMs} ms',
          monospace: true,
        ),
      if (metrics.callSetupLatencyMs != null)
        DiagnosticsKeyValueRow(
          label: 'Call setup latency',
          value: '${metrics.callSetupLatencyMs} ms',
          monospace: true,
        ),
      if (metrics.timeToFirstRtpMs != null)
        DiagnosticsKeyValueRow(
          label: 'Time to first RTP',
          value: '${metrics.timeToFirstRtpMs} ms',
          monospace: true,
        ),
      if (metrics.iceGatheringLatencyMs != null)
        DiagnosticsKeyValueRow(
          label: 'ICE gathering',
          value: '${metrics.iceGatheringLatencyMs} ms',
          monospace: true,
        ),
      if (metrics.signalingLatencyMs != null)
        DiagnosticsKeyValueRow(
          label: 'Signaling',
          value: '${metrics.signalingLatencyMs} ms',
          monospace: true,
        ),
      if (metrics.mediaEstablishmentLatencyMs != null)
        DiagnosticsKeyValueRow(
          label: 'Media establishment',
          value: '${metrics.mediaEstablishmentLatencyMs} ms',
          monospace: true,
        ),
    ];

    return Container(
      key: ValueKey('latency_card_${metrics.timestamp}'),
      margin: const EdgeInsets.only(bottom: spacingM),
      padding: const EdgeInsets.all(spacingM),
      decoration: BoxDecoration(
        color: darkSurfaceColor,
        borderRadius: BorderRadius.circular(spacingS),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                DateTime.fromMillisecondsSinceEpoch(
                  metrics.timestamp,
                ).toLocal().toIso8601String().substring(11, 19),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          if (metrics.callId != null)
            Padding(
              padding: const EdgeInsets.only(top: spacingXXS),
              child: Text(
                'Call ${metrics.callId}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          const SizedBox(height: spacingS),
          ...rows,
          if (metrics.milestones.isNotEmpty)
            MilestoneList(milestones: metrics.milestones),
        ],
      ),
    );
  }
}

/// The per-milestone offsets inside a metrics emission, ordered by time.
class MilestoneList extends StatelessWidget {
  /// Creates the milestone breakdown.
  const MilestoneList({required this.milestones, super.key});

  /// Milestone name to offset in milliseconds.
  final Map<String, int> milestones;

  @override
  Widget build(BuildContext context) {
    final entries = milestones.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: spacingXL),
        Text('Milestones', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: spacingXS),
        ...entries.map(
          (e) => DiagnosticsKeyValueRow(
            label: e.key,
            value: '${e.value} ms',
            monospace: true,
          ),
        ),
      ],
    );
  }
}
