import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/version_utils.dart';

class BottomConnectionActionWidget extends StatefulWidget {
  final String buttonTitle;
  final VoidCallback? onPressed;
  final bool isLoading;

  const BottomConnectionActionWidget({
    super.key,
    required this.buttonTitle,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  State<BottomConnectionActionWidget> createState() =>
      _BottomConnectionActionWidgetState();
}

class _BottomConnectionActionWidgetState
    extends State<BottomConnectionActionWidget> {
  @override
  Widget build(BuildContext context) {
    // Watch ProfileProvider to rebuild when environment changes
    final isDevEnvironment = context.watch<ProfileProvider>().isDevEnvironment;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onPressed,
            child: widget.isLoading
                ? SizedBox(
                    width: spacingXL,
                    height: spacingXL,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(widget.buttonTitle),
          ),
        ),
        const SizedBox(height: spacingS),
        FutureBuilder<String>(
          future: VersionUtils.getVersionString(
            isDevEnvironment: isDevEnvironment,
          ),
          builder: (context, snapshot) {
            return Text(
              snapshot.data ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            );
          },
        ),
      ],
    );
  }
}
