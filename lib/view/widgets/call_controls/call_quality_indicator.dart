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
              // Quality indicator dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getQualityColor(quality),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // Quality text
              Text(
                quality.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              // Details button
              GestureDetector(
                onTap: () => _showQualityBottomSheet(context, metrics),
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
              ),
            ],
          ),
        );
      },
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

  void _showQualityBottomSheet(BuildContext context, CallQualityMetrics? metrics) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CallQualityMetricsBottomSheet(metrics: metrics),
    );
  }
}