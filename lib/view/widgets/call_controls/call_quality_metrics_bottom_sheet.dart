import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/audio_waveform.dart';
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';

class CallQualityMetricsBottomSheet extends StatelessWidget {
  final CallQualityMetrics? metrics;

  const CallQualityMetricsBottomSheet({
    super.key,
    this.metrics,
  });

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
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Audio Levels Section
                  _buildAudioLevelsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Metrics Section
                  _buildMetricsSection(),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioLevelsSection() {
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
          audioStats: metrics?.inboundAudio,
          color: Colors.green,
        ),
        
        const SizedBox(height: 16),
        
        // Outbound Audio Waveform
        AudioWaveform(
          label: 'Outbound Level',
          audioStats: metrics?.outboundAudio,
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildMetricsSection() {
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
              _buildMetricRow(
                'Quality',
                metrics?.quality.toString() ?? 'Unknown',
                _getQualityColor(metrics?.quality),
              ),
              const Divider(color: Colors.grey),
              _buildMetricRow(
                'MOS Score',
                metrics != null ? '${metrics!.mos.toStringAsFixed(2)}' : 'N/A',
                Colors.white,
              ),
              const Divider(color: Colors.grey),
              _buildMetricRow(
                'Jitter',
                metrics != null ? '${(metrics!.jitter * 1000).toStringAsFixed(1)} ms' : 'N/A',
                Colors.white,
              ),
              const Divider(color: Colors.grey),
              _buildMetricRow(
                'Round Trip Time',
                metrics != null ? '${(metrics!.rtt * 1000).toStringAsFixed(1)} ms' : 'N/A',
                Colors.white,
              ),
            ],
          ),
        ),
        
        if (metrics != null) ...[
          const SizedBox(height: 16),
          _buildQualityExplanation(),
        ],
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
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

  Widget _buildQualityExplanation() {
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