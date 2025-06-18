import 'dart:math';
import 'package:flutter/material.dart';

class AudioWaveform extends StatefulWidget {
  final String label;
  final Map<String, dynamic>? audioStats;
  final Color color;
  final double height;

  const AudioWaveform({
    super.key,
    required this.label,
    this.audioStats,
    this.color = Colors.blue,
    this.height = 60,
  });

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final List<double> _waveformData = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    )..repeat();
    
    // Initialize with some sample data
    _generateWaveformData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _generateWaveformData() {
    _waveformData.clear();
    // Generate 50 data points for the waveform
    for (int i = 0; i < 50; i++) {
      // Simulate audio levels based on stats if available
      double level = _getAudioLevel();
      _waveformData.add(level);
    }
  }

  double _getAudioLevel() {
    if (widget.audioStats != null) {
      // Try to extract audio level from stats
      final audioLevel = widget.audioStats?['audioLevel'];
      if (audioLevel is num) {
        return (audioLevel.toDouble() * 100).clamp(0.0, 100.0);
      }
      
      // Fallback to packet-based estimation
      final packetsReceived = widget.audioStats?['packetsReceived'];
      final packetsLost = widget.audioStats?['packetsLost'];
      if (packetsReceived is num && packetsLost is num) {
        final total = packetsReceived.toDouble() + packetsLost.toDouble();
        if (total > 0) {
          final quality = (packetsReceived.toDouble() / total) * 100;
          return quality.clamp(0.0, 100.0);
        }
      }
    }
    
    // Generate random data for demonstration
    return _random.nextDouble() * 80 + 10; // 10-90 range
  }

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
          Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: widget.height,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                // Update waveform data periodically
                if (_animationController.value == 0) {
                  _generateWaveformData();
                }
                return CustomPaint(
                  size: Size(double.infinity, widget.height),
                  painter: WaveformPainter(
                    waveformData: _waveformData,
                    color: widget.color,
                    animationValue: _animationController.value,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (widget.audioStats != null) _buildStatsInfo(),
        ],
      ),
    );
  }

  Widget _buildStatsInfo() {
    final stats = widget.audioStats!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stats['packetsReceived'] != null)
          _buildStatRow('Packets Received', '${stats['packetsReceived']}'),
        if (stats['packetsLost'] != null)
          _buildStatRow('Packets Lost', '${stats['packetsLost']}'),
        if (stats['bytesReceived'] != null)
          _buildStatRow('Bytes Received', '${stats['bytesReceived']}'),
        if (stats['bytesSent'] != null)
          _buildStatRow('Bytes Sent', '${stats['bytesSent']}'),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color color;
  final double animationValue;

  WaveformPainter({
    required this.waveformData,
    required this.color,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    final barWidth = size.width / waveformData.length;
    
    for (int i = 0; i < waveformData.length; i++) {
      final barHeight = (waveformData[i] / 100) * size.height;
      final x = i * barWidth;
      final y = size.height - barHeight;
      
      // Add some animation effect
      final animatedHeight = barHeight * (0.7 + 0.3 * sin(animationValue * 2 * pi + i * 0.1));
      final animatedY = size.height - animatedHeight;
      
      final rect = Rect.fromLTWH(
        x,
        animatedY,
        barWidth * 0.8, // Leave some space between bars
        animatedHeight,
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}