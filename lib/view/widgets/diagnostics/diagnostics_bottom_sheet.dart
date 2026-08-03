import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/diagnostics/catalog_panel.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/diagnostics/debug_config_panel.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/diagnostics/diagnostics_common.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/diagnostics/latency_panel.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/diagnostics/logs_panel.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/diagnostics/pre_call_panel.dart';

/// The diagnostics surface for the SDK's reporting and diagnostics features.
///
/// Tabs map to what the SDK actually exposes:
///   Latency  — live, stream-driven
///   Logs     — poll-only via LogCollector
///   Catalog  — static error/warning reference tables
///   Config   — the debug fields on the active Config
///   Pre-call — an on-demand diagnostic that places a real call
///
/// The Config tab also lists the components that ship in the SDK but are not
/// connected to anything, so the gap is visible rather than implied.
class DiagnosticsBottomSheet extends StatelessWidget {
  /// Creates the diagnostics sheet.
  const DiagnosticsBottomSheet({super.key});

  /// Opens the sheet, matching the app's other modal surfaces.
  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DiagnosticsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(spacingL),
            topRight: Radius.circular(spacingL),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: spacingM),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                spacingXXL,
                spacingM,
                spacingS,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Diagnostics',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('diagnostics_close'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: primaryColor,
              unselectedLabelColor: telnyx_grey,
              indicatorColor: active_text_field_color,
              tabs: [
                Tab(text: 'Latency'),
                Tab(text: 'Logs'),
                Tab(text: 'Catalog'),
                Tab(text: 'Config'),
                Tab(text: 'Pre-call'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  DiagnosticsTabBody(child: LatencyPanel()),
                  DiagnosticsTabBody(child: LogsPanel()),
                  DiagnosticsTabBody(child: CatalogPanel()),
                  DiagnosticsTabBody(child: DebugConfigTab()),
                  DiagnosticsTabBody(child: PreCallPanel()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scroll + padding wrapper shared by every tab.
class DiagnosticsTabBody extends StatelessWidget {
  /// Wraps a tab's content.
  const DiagnosticsTabBody({required this.child, super.key});

  /// The tab content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(spacingXXL, 0, spacingXXL, spacingXXL),
      child: child,
    );
  }
}

/// The Config tab: active debug config plus the unwired-capability notices.
class DebugConfigTab extends StatelessWidget {
  /// Creates the config tab.
  const DebugConfigTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DebugConfigPanel(),
        DiagnosticsSectionHeader(
          title: 'Not available',
          subtitle: 'Shipped in the SDK but not connected to anything',
        ),
        DiagnosticsUnavailableTile(
          title: 'Quality warnings',
          reason:
              'QualityWarningMonitor is exported but the SDK never '
              'instantiates it. Surfacing live warnings needs a '
              'CallQualityMetrics to StatsInterval adapter in the app.',
        ),
        DiagnosticsUnavailableTile(
          title: 'Runtime error and warning events',
          reason:
              'TelnyxErrorEvent and TelnyxWarningEvent are exported but '
              'never emitted, and TelnyxClient exposes no onTelnyxError hook. '
              'The Catalog tab is reference data only.',
        ),
        DiagnosticsUnavailableTile(
          title: 'Signaling health',
          reason:
              'SignalingHealthMonitor is not exported from the package and '
              'Peer does not implement ISignalingHealthSession, so there is no '
              'production session to observe.',
        ),
      ],
    );
  }
}
