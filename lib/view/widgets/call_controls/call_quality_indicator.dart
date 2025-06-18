import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/call_controls/call_quality_metrics_bottom_sheet.dart';
import 'package:telnyx_webrtc/model/call_quality.dart';
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';

class CallQualityIndicator extends StatelessWidget {
  const CallQualityIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TelnyxClientViewModel>(
      builder: (context, viewModel, child) {
        final metrics = viewModel.callQualityMetrics;
        final quality = metrics?.quality ?? CallQuality.unknown;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              QualityDot(quality: quality),
              const SizedBox(width: 8),
              QualityText(quality: quality),
              const SizedBox(width: 8),
              DetailsButton(
                onTap: () => _showQualityBottomSheet(context, metrics),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQualityBottomSheet(BuildContext context, CallQualityMetrics? metrics) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const CallQualityMetricsBottomSheet(),
    );
  }
}

class QualityDot extends StatelessWidget {
  final CallQuality quality;

  const QualityDot({super.key, required this.quality});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _getQualityColor(quality),
        shape: BoxShape.circle,
      ),
    );
  }

  Color _getQualityColor(CallQuality quality) {
    switch (quality) {
      case CallQuality.excellent:
        return Colors.green;
      case CallQuality.good:
        return Colors.lightGreen;
      case CallQuality.fair:
        return Colors.yellow;
      case CallQuality.poor:
        return Colors.orange;
      case CallQuality.bad:
        return Colors.red;
      case CallQuality.unknown:
        return Colors.grey;
    }
  }
}

class QualityText extends StatelessWidget {
  final CallQuality quality;

  const QualityText({super.key, required this.quality});

  @override
  Widget build(BuildContext context) {
    return Text(
      _getQualityDisplayText(quality),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String _getQualityDisplayText(CallQuality quality) {
    switch (quality) {
      case CallQuality.excellent:
        return 'Excellent';
      case CallQuality.good:
        return 'Good';
      case CallQuality.fair:
        return 'Fair';
      case CallQuality.poor:
        return 'Poor';
      case CallQuality.bad:
        return 'Bad';
      case CallQuality.unknown:
        return 'Unknown';
    }
  }
}

class DetailsButton extends StatelessWidget {
  final VoidCallback onTap;

  const DetailsButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}