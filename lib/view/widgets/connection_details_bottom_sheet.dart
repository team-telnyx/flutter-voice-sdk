import 'package:flutter/material.dart';
import 'package:telnyx_webrtc/model/socket_connection_metrics.dart';

class ConnectionDetailsBottomSheet extends StatelessWidget {
  final SocketConnectionMetrics? metrics;

  const ConnectionDetailsBottomSheet({
    super.key,
    this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Connection Details',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (metrics == null)
            const LoadingStateWidget()
          else
            MetricsContentWidget(metrics: metrics!),
        ],
      ),
    );
  }
}

class LoadingStateWidget extends StatelessWidget {
  const LoadingStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Center(child: CircularProgressIndicator()),
        SizedBox(height: 16),
        Center(
          child: Text(
            'Loading connection metrics...',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class MetricsContentWidget extends StatelessWidget {
  final SocketConnectionMetrics metrics;

  const MetricsContentWidget({
    super.key,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quality indicator
        QualityIndicatorWidget(quality: metrics.quality),
        const SizedBox(height: 24),

        // Connection metrics section
        const SectionHeaderWidget(title: 'Connection Metrics'),
        const SizedBox(height: 16),

        MetricRowWidget(
          label: 'Interval',
          value: _formatMetric(metrics.intervalMs, 'ms'),
        ),
        MetricRowWidget(
          label: 'Average Interval',
          value: _formatMetric(metrics.averageIntervalMs, 'ms'),
        ),
        MetricRowWidget(
          label: 'Jitter',
          value: _formatMetric(metrics.jitterMs, 'ms'),
        ),
        MetricRowWidget(
          label: 'Min Interval',
          value: _formatMetric(metrics.minIntervalMs, 'ms'),
        ),
        MetricRowWidget(
          label: 'Max Interval',
          value: _formatMetric(metrics.maxIntervalMs, 'ms'),
        ),
        MetricRowWidget(
          label: 'Success Rate',
          value: '${metrics.getSuccessRate().toStringAsFixed(1)}%',
        ),

        const SizedBox(height: 24),

        // Ping statistics section
        const SectionHeaderWidget(title: 'Ping Statistics'),
        const SizedBox(height: 16),

        MetricRowWidget(
          label: 'Total Pings',
          value: metrics.totalPings.toString(),
        ),
        if (metrics.missedPings > 0)
          MetricRowWidget(
            label: 'Missed Pings',
            value: metrics.missedPings.toString(),
          ),
      ],
    );
  }

  String _formatMetric(int? value, String unit) {
    if (value == null) return 'Not available';
    return '$value $unit';
  }
}

class QualityIndicatorWidget extends StatelessWidget {
  final SocketConnectionQuality quality;

  const QualityIndicatorWidget({
    super.key,
    required this.quality,
  });

  @override
  Widget build(BuildContext context) {
    final qualityColor = _getQualityColor(quality);
    final qualityText = _getQualityText(quality);

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: qualityColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          qualityText,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: qualityColor,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Color _getQualityColor(SocketConnectionQuality quality) {
    switch (quality) {
      case SocketConnectionQuality.disconnected:
        return Colors.red;
      case SocketConnectionQuality.calculating:
        return Colors.orange;
      case SocketConnectionQuality.excellent:
        return Colors.green;
      case SocketConnectionQuality.good:
        return Colors.lightGreen;
      case SocketConnectionQuality.fair:
        return Colors.orange;
      case SocketConnectionQuality.poor:
        return Colors.red;
    }
  }

  String _getQualityText(SocketConnectionQuality quality) {
    switch (quality) {
      case SocketConnectionQuality.disconnected:
        return 'Disconnected';
      case SocketConnectionQuality.calculating:
        return 'Calculating...';
      case SocketConnectionQuality.excellent:
        return 'Excellent';
      case SocketConnectionQuality.good:
        return 'Good';
      case SocketConnectionQuality.fair:
        return 'Fair';
      case SocketConnectionQuality.poor:
        return 'Poor';
    }
  }
}

class SectionHeaderWidget extends StatelessWidget {
  final String title;

  const SectionHeaderWidget({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    );
  }
}

class MetricRowWidget extends StatelessWidget {
  final String label;
  final String value;

  const MetricRowWidget({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
