import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/audio_waveform.dart';
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';

class CallQualityMetricsBottomSheet extends StatelessWidget {
  const CallQualityMetricsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Call Quality Metrics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // Content - Now using Consumer to get real-time updates
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Consumer<TelnyxClientViewModel>(
                builder: (context, viewModel, child) {
                  final metrics = viewModel.callQualityMetrics;

                  return Column(
                    children: [
                      // Audio Levels Section
                      AudioLevelsSection(metrics: metrics),

                      const SizedBox(height: 24),

                      // Metrics Section
                      MetricsSection(metrics: metrics),

                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AudioLevelsSection extends StatelessWidget {
  final CallQualityMetrics? metrics;

  const AudioLevelsSection({super.key, this.metrics});

  @override
  Widget build(BuildContext context) {
    return Consumer<TelnyxClientViewModel>(
      builder: (context, viewModel, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Audio Levels',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Inbound Audio Waveform
            AudioWaveform(
              label: 'Inbound Level',
              audioLevels: viewModel.inboundAudioLevels,
              color: Colors.green,
            ),

            const SizedBox(height: 16),

            // Outbound Audio Waveform
            AudioWaveform(
              label: 'Outbound Level',
              audioLevels: viewModel.outboundAudioLevels,
              color: Colors.blue,
            ),
          ],
        );
      },
    );
  }
}

class MetricsSection extends StatelessWidget {
  final CallQualityMetrics? metrics;

  const MetricsSection({super.key, this.metrics});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quality Metrics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              MetricRow(
                label: 'Quality',
                value: _getQualityDisplayText(metrics?.quality),
                valueColor: _getQualityColor(metrics?.quality),
              ),
              const Divider(color: Colors.grey),
              MetricRow(
                label: 'MOS Score',
                value: metrics != null
                    ? '${metrics!.mos.toStringAsFixed(2)}'
                    : 'N/A',
                valueColor: Colors.white,
              ),
              const Divider(color: Colors.grey),
              MetricRow(
                label: 'Jitter',
                value: metrics != null
                    ? '${(metrics!.jitter * 1000).toStringAsFixed(1)} ms'
                    : 'N/A',
                valueColor: Colors.white,
              ),
              const Divider(color: Colors.grey),
              MetricRow(
                label: 'Round Trip Time',
                value: metrics != null
                    ? '${(metrics!.rtt * 1000).toStringAsFixed(1)} ms'
                    : 'N/A',
                valueColor: Colors.white,
              ),
            ],
          ),
        ),
        if (metrics != null) ...[
          const SizedBox(height: 16),
          const QualityExplanation(),
        ],
      ],
    );
  }

  String _getQualityDisplayText(dynamic quality) {
    if (quality == null) return 'Unknown';

    final qualityStr = quality.toString().toLowerCase();
    switch (qualityStr) {
      case 'excellent':
        return 'Excellent';
      case 'good':
        return 'Good';
      case 'fair':
        return 'Fair';
      case 'poor':
        return 'Poor';
      case 'bad':
        return 'Bad';
      default:
        return 'Unknown';
    }
  }

  Color _getQualityColor(dynamic quality) {
    if (quality == null) return Colors.grey;

    final qualityStr = quality.toString().toLowerCase();
    switch (qualityStr) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.lightGreen;
      case 'fair':
        return Colors.yellow;
      case 'poor':
        return Colors.orange;
      case 'bad':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const MetricRow({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class QualityExplanation extends StatelessWidget {
  const QualityExplanation({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quality Explanation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '• MOS (Mean Opinion Score): Ranges from 1.0 to 5.0, with higher values indicating better quality\n'
            '• Jitter: Variation in packet arrival times. Lower values are better\n'
            '• RTT (Round Trip Time): Time for a packet to travel to destination and back. Lower values are better',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
