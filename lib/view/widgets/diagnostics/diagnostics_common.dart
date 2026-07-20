import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';

/// Section heading inside the diagnostics sheet.
class DiagnosticsSectionHeader extends StatelessWidget {
  /// Creates a section heading with an optional trailing action.
  const DiagnosticsSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  /// The section title.
  final String title;

  /// Optional explanatory line under the title.
  final String? subtitle;

  /// Optional trailing widget, typically a button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: spacingL, bottom: spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: spacingXXS),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A label/value row used throughout the diagnostics panels.
class DiagnosticsKeyValueRow extends StatelessWidget {
  /// Creates a key/value row.
  const DiagnosticsKeyValueRow({
    required this.label,
    required this.value,
    this.monospace = false,
    super.key,
  });

  /// The left-hand label.
  final String label;

  /// The right-hand value.
  final String value;

  /// Whether to render the value in a monospace face, for numbers and ids.
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: spacingXXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: monospace ? 'monospace' : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder for a diagnostics capability that exists in the SDK but is not
/// connected to anything, so it has no data to show.
///
/// These are rendered deliberately rather than omitted: VSD-419 shipped several
/// components that are exported but never instantiated by the SDK, and hiding
/// them would make the feature look complete when it is not.
class DiagnosticsUnavailableTile extends StatelessWidget {
  /// Creates an unavailable-capability tile.
  const DiagnosticsUnavailableTile({
    required this.title,
    required this.reason,
    super.key,
  });

  /// Name of the unavailable capability.
  final String title;

  /// Why it cannot be shown, in concrete terms.
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: spacingS),
      padding: const EdgeInsets.all(spacingM),
      decoration: BoxDecoration(
        color: darkSurfaceColor,
        borderRadius: BorderRadius.circular(spacingS),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Not `iconSize` (72.0) — that constant is for the large hero icons.
          const Icon(Icons.link_off, size: fontSizeL, color: telnyx_grey),
          const SizedBox(width: spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: spacingXXS),
                Text(reason, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when a panel has nothing to display yet.
class DiagnosticsEmptyState extends StatelessWidget {
  /// Creates an empty-state message.
  const DiagnosticsEmptyState({required this.message, super.key});

  /// The message to show.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: spacingL),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}
