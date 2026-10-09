import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_flutter_webrtc/view/widgets/diagnostics/diagnostics_common.dart';
import 'package:telnyx_webrtc/model/errors/sdk_errors.dart';
import 'package:telnyx_webrtc/model/errors/sdk_warnings.dart';

/// Browsable reference for the SDK's error and warning registries.
///
/// This is a static lookup table, not a live feed. VSD-419 defines
/// `TelnyxErrorEvent` / `TelnyxWarningEvent` but nothing in the SDK ever emits
/// them and there is no `onTelnyxError` hook, so runtime occurrences cannot be
/// listed here — see the unavailable tiles at the bottom of the sheet.
class CatalogPanel extends StatefulWidget {
  /// Creates the catalog panel.
  const CatalogPanel({super.key});

  @override
  State<CatalogPanel> createState() => _CatalogPanelState();
}

class _CatalogPanelState extends State<CatalogPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();

    bool matches(int code, String name, String message) {
      if (query.isEmpty) {
        return true;
      }
      return '$code'.contains(query) ||
          name.toLowerCase().contains(query) ||
          message.toLowerCase().contains(query);
    }

    final errors = sdkErrors.entries
        .where((e) => matches(e.key, e.value.name, e.value.message))
        .toList();
    final warnings = sdkWarnings.entries
        .where((e) => matches(e.key, e.value.name, e.value.message))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiagnosticsSectionHeader(
          title: 'Error & warning catalog',
          subtitle:
              '${sdkErrors.length} errors · ${sdkWarnings.length} warnings · '
              'reference only',
        ),
        TextField(
          key: const ValueKey('diagnostics_catalog_search'),
          decoration: const InputDecoration(
            hintText: 'Filter by code, name or message',
            prefixIcon: Icon(Icons.search, size: fontSizeL),
            isDense: true,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: spacingS),
        if (errors.isEmpty && warnings.isEmpty)
          const DiagnosticsEmptyState(message: 'Nothing matches that filter.'),
        ...errors.map(
          (e) => CatalogEntryTile(
            code: e.key,
            name: e.value.name,
            message: e.value.message,
            description: e.value.description,
            causes: e.value.causes,
            solutions: e.value.solutions,
            isError: true,
            fatal: e.value.fatal,
          ),
        ),
        ...warnings.map(
          (e) => CatalogEntryTile(
            code: e.key,
            name: e.value.name,
            message: e.value.message,
            description: e.value.description,
            causes: e.value.causes,
            solutions: e.value.solutions,
            isError: false,
            fatal: false,
          ),
        ),
      ],
    );
  }
}

/// One catalog entry, expandable to show causes and solutions.
class CatalogEntryTile extends StatelessWidget {
  /// Creates a catalog entry tile.
  const CatalogEntryTile({
    required this.code,
    required this.name,
    required this.message,
    required this.description,
    required this.causes,
    required this.solutions,
    required this.isError,
    required this.fatal,
    super.key,
  });

  /// Numeric code, which is the registry map key.
  final int code;

  /// Symbolic name, such as `HIGH_RTT`.
  final String name;

  /// Short message.
  final String message;

  /// Longer description.
  final String description;

  /// Known causes.
  final List<String> causes;

  /// Suggested solutions.
  final List<String> solutions;

  /// Whether this is an error rather than a warning.
  final bool isError;

  /// Whether the error is fatal. Always false for warnings.
  final bool fatal;

  @override
  Widget build(BuildContext context) {
    final accent = isError ? Colors.red.shade700 : Colors.orange.shade800;

    return Theme(
      // Strip the default divider lines so the list reads as one block.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('diagnostics_catalog_$code'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: spacingS),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: spacingXS,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(spacingXS),
              ),
              child: Text(
                '$code',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: fontSizeS,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: spacingS),
            Expanded(
              child: Text(
                name,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            if (fatal)
              Text(
                'FATAL',
                style: TextStyle(
                  fontSize: fontSizeXS + 2,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
          ],
        ),
        subtitle: Text(message, style: Theme.of(context).textTheme.labelSmall),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: telnyx_soft_black),
                ),
                if (causes.isNotEmpty)
                  CatalogBulletList(title: 'Causes', items: causes),
                if (solutions.isNotEmpty)
                  CatalogBulletList(title: 'Solutions', items: solutions),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled bullet list inside an expanded catalog entry.
class CatalogBulletList extends StatelessWidget {
  /// Creates a bullet list.
  const CatalogBulletList({
    required this.title,
    required this.items,
    super.key,
  });

  /// Heading for the list.
  final String title;

  /// The bullet items.
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: spacingXXS),
              child: Text(
                '·  $item',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
