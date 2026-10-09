import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/diagnostics/diagnostics_common.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/utils/pre_call_diagnosis.dart';

/// Runs [PreCallDiagnostic] and renders the resulting [DiagnosticReport].
///
/// This places a REAL outbound call to the TeXML number provided, so it is
/// gated behind an explicit confirmation. The SDK offers no progress events
/// and a 30s internal timeout, so the run is a single blocking await.
class PreCallPanel extends StatefulWidget {
  /// Creates the pre-call diagnostic panel.
  const PreCallPanel({super.key});

  @override
  State<PreCallPanel> createState() => _PreCallPanelState();
}

class _PreCallPanelState extends State<PreCallPanel> {
  final TextEditingController _destinationController = TextEditingController();

  bool _running = false;
  DiagnosticReport? _report;
  String? _error;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndRun() async {
    final destination = _destinationController.text.trim();
    if (destination.isEmpty) {
      setState(() => _error = 'Enter a TeXML destination number first.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PreCallConfirmDialog(destination: destination),
    );
    if (confirmed != true) {
      return;
    }
    if (!mounted) {
      return;
    }
    await _run(destination);
  }

  Future<void> _run(String destination) async {
    final viewModel = context.read<TelnyxClientViewModel>();
    final config = viewModel.activeConfig;
    if (config == null) {
      setState(
        () => _error =
            'Connect first — the diagnostic needs SIP '
            'credentials from the active profile.',
      );
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _report = null;
    });

    try {
      // PreCallDiagnosisOptions takes either a token or a user/password pair;
      // pull whichever the active config carries.
      final options = PreCallDiagnosisOptions(
        texMLApplicationNumber: destination,
        sipToken: config is TokenConfig ? config.sipToken : null,
        sipUser: config is CredentialConfig ? config.sipUser : null,
        sipPassword: config is CredentialConfig ? config.sipPassword : null,
        sipCallerIDName: config.sipCallerIDName,
        sipCallerIDNumber: config.sipCallerIDNumber,
      );
      final report = await PreCallDiagnostic.run(options);
      if (!mounted) {
        return;
      }
      setState(() => _report = report);
    } on PreCallDiagnosticException catch (e) {
      if (!mounted) {
        return;
      }
      setState(
        () => _error =
            '${e.reason.name}: ${e.message}'
            '${e.sipCode != null ? ' (SIP ${e.sipCode})' : ''}',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DiagnosticsSectionHeader(
          title: 'Pre-call diagnostic',
          subtitle: 'Places a real, billable call · about 30 seconds',
        ),
        TextField(
          key: const ValueKey('diagnostics_precall_destination'),
          controller: _destinationController,
          enabled: !_running,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'TeXML destination number',
            hintText: '+1XXXXXXXXXX',
            isDense: true,
          ),
        ),
        const SizedBox(height: spacingM),
        SizedBox(
          width: double.infinity,
          child: Semantics(
            identifier: 'diagnostics_precall_run',
            container: true,
            child: ElevatedButton(
              key: const ValueKey('diagnostics_precall_run'),
              onPressed: _running ? null : _confirmAndRun,
              child: _running
                  ? const SizedBox(
                      height: spacingL,
                      width: spacingL,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Run pre-call diagnostic'),
            ),
          ),
        ),
        if (_running)
          const Padding(
            padding: EdgeInsets.only(top: spacingS),
            child: Text(
              'Calling… the SDK reports no progress until it finishes.',
              textAlign: TextAlign.center,
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: spacingM),
            child: Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.red.shade700),
            ),
          ),
        if (_report != null) DiagnosticReportView(report: _report!),
      ],
    );
  }
}

/// Confirmation shown before placing the billable diagnostic call.
class PreCallConfirmDialog extends StatelessWidget {
  /// Creates the confirmation dialog.
  const PreCallConfirmDialog({required this.destination, super.key});

  /// The number that will be dialled.
  final String destination;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Place a real call?'),
      content: Text(
        'This dials $destination for real and may incur charges.\n\n'
        'It takes about 30 seconds and cannot be cancelled once started.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('diagnostics_precall_confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Run'),
        ),
      ],
    );
  }
}

/// Renders a completed [DiagnosticReport].
class DiagnosticReportView extends StatelessWidget {
  /// Creates the report view.
  const DiagnosticReportView({required this.report, super.key});

  /// The report to render.
  final DiagnosticReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: spacingM),
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
                'MOS ${report.mos.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                report.quality.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: active_text_field_color,
                ),
              ),
            ],
          ),
          const Divider(height: spacingXL),
          MinMaxAverageRow(label: 'Jitter', stats: report.jitter, unit: 'ms'),
          MinMaxAverageRow(label: 'RTT', stats: report.rtt, unit: 'ms'),
          const Divider(height: spacingXL),
          DiagnosticsKeyValueRow(
            label: 'Packets sent',
            value: '${report.sessionStats.packetsSent}',
            monospace: true,
          ),
          DiagnosticsKeyValueRow(
            label: 'Packets received',
            value: '${report.sessionStats.packetsReceived}',
            monospace: true,
          ),
          DiagnosticsKeyValueRow(
            label: 'Packets lost',
            value: '${report.sessionStats.packetsLost}',
            monospace: true,
          ),
          DiagnosticsKeyValueRow(
            label: 'Bytes sent',
            value: '${report.sessionStats.bytesSent}',
            monospace: true,
          ),
          DiagnosticsKeyValueRow(
            label: 'Bytes received',
            value: '${report.sessionStats.bytesReceived}',
            monospace: true,
          ),
          DiagnosticsKeyValueRow(
            label: 'ICE candidates',
            value: '${report.iceCandidateStats.length}',
            monospace: true,
          ),
        ],
      ),
    );
  }
}

/// A min/max/average triple from a [DiagnosticReport].
class MinMaxAverageRow extends StatelessWidget {
  /// Creates a min/max/average row.
  const MinMaxAverageRow({
    required this.label,
    required this.stats,
    required this.unit,
    super.key,
  });

  /// Row label.
  final String label;

  /// The statistics to render.
  final MinMaxAverage stats;

  /// Unit suffix.
  final String unit;

  @override
  Widget build(BuildContext context) {
    return DiagnosticsKeyValueRow(
      label: label,
      value:
          '${stats.min.toStringAsFixed(1)} / '
          '${stats.average.toStringAsFixed(1)} / '
          '${stats.max.toStringAsFixed(1)} $unit',
      monospace: true,
    );
  }
}
