import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_webrtc/model/audio_codec.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';

class CodecSelectorDialog extends StatefulWidget {
  const CodecSelectorDialog({Key? key}) : super(key: key);

  @override
  State<CodecSelectorDialog> createState() => _CodecSelectorDialogState();
}

class _CodecSelectorDialogState extends State<CodecSelectorDialog> {
  late List<AudioCodec> _availableCodecs;
  late List<AudioCodec> _selectedCodecs;
  late Map<String, bool> _codecSelectionStatus;

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<TelnyxClientViewModel>();

    // Get available codecs from the view model
    _availableCodecs = List.from(viewModel.supportedCodecs);

    // Initialize selected codecs from current preferences
    _selectedCodecs = List.from(viewModel.preferredCodecs);

    // Initialize selection status map
    _codecSelectionStatus = {};
    for (var codec in _availableCodecs) {
      final codecKey = '${codec.mimeType}_${codec.clockRate}';
      _codecSelectionStatus[codecKey] = _selectedCodecs.any(
        (selected) =>
            selected.mimeType == codec.mimeType &&
            selected.clockRate == codec.clockRate,
      );
    }
  }

  String _getCodecDisplayName(AudioCodec codec) {
    final baseName = codec.mimeType?.replaceAll('audio/', '') ?? 'Unknown';
    final rate = codec.clockRate != null
        ? '${(codec.clockRate! / 1000).toStringAsFixed(0)}kHz'
        : '';
    final channels =
        codec.channels != null && codec.channels! > 1 ? ' Stereo' : '';
    return '$baseName $rate$channels'.trim();
  }

  String _getCodecDescription(AudioCodec codec) {
    switch (codec.mimeType) {
      case 'audio/opus':
        return 'High quality, low latency codec';
      case 'audio/PCMU':
        return 'G.711 μ-law - Standard fallback';
      case 'audio/PCMA':
        return 'G.711 A-law - Alternative fallback';
      case 'audio/G722':
        return 'Wideband codec for better quality';
      case 'audio/ILBC':
        return 'Good for poor network conditions';
      case 'audio/telephone-event':
        return 'DTMF tone support';
      default:
        return '';
    }
  }

  void _toggleCodecSelection(AudioCodec codec) {
    final codecKey = '${codec.mimeType}_${codec.clockRate}';
    setState(() {
      _codecSelectionStatus[codecKey] =
          !(_codecSelectionStatus[codecKey] ?? false);

      if (_codecSelectionStatus[codecKey]!) {
        // Add to selected list if not already there
        if (!_selectedCodecs.any(
          (c) => c.mimeType == codec.mimeType && c.clockRate == codec.clockRate,
        )) {
          _selectedCodecs.add(codec);
        }
      } else {
        // Remove from selected list
        _selectedCodecs.removeWhere(
          (c) => c.mimeType == codec.mimeType && c.clockRate == codec.clockRate,
        );
      }
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final codec = _selectedCodecs.removeAt(oldIndex);
      _selectedCodecs.insert(newIndex, codec);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Audio Codec Preferences'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select codecs and drag to reorder by preference',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: theme.primaryColor,
                      unselectedLabelColor: theme.textTheme.bodyMedium?.color,
                      tabs: const [
                        Tab(text: 'Available'),
                        Tab(text: 'Selected'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Available codecs tab
                          ListView.builder(
                            itemCount: _availableCodecs.length,
                            itemBuilder: (context, index) {
                              final codec = _availableCodecs[index];
                              final codecKey =
                                  '${codec.mimeType}_${codec.clockRate}';
                              final isSelected =
                                  _codecSelectionStatus[codecKey] ?? false;

                              return CheckboxListTile(
                                title: Text(_getCodecDisplayName(codec)),
                                subtitle: Text(_getCodecDescription(codec)),
                                value: isSelected,
                                onChanged: (bool? value) {
                                  _toggleCodecSelection(codec);
                                },
                                secondary: Icon(
                                  Icons.audiotrack,
                                  color: isSelected
                                      ? theme.primaryColor
                                      : theme.disabledColor,
                                ),
                              );
                            },
                          ),
                          // Selected codecs tab with reordering
                          _selectedCodecs.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.queue_music_outlined,
                                        size: 64,
                                        color: theme.disabledColor,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No codecs selected',
                                        style: TextStyle(
                                          color: theme.disabledColor,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Select codecs from the Available tab',
                                        style: TextStyle(
                                          color: theme.disabledColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ReorderableListView.builder(
                                  itemCount: _selectedCodecs.length,
                                  onReorder: _onReorder,
                                  itemBuilder: (context, index) {
                                    final codec = _selectedCodecs[index];
                                    return ListTile(
                                      key: ValueKey(
                                          '${codec.mimeType}_${codec.clockRate}'),
                                      leading: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: theme.primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      title: Text(_getCodecDisplayName(codec)),
                                      subtitle:
                                          Text(_getCodecDescription(codec)),
                                      trailing: const Icon(Icons.drag_handle),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedCodecs.isNotEmpty) ...[
              const Divider(),
              Text(
                'Priority: ${_selectedCodecs.map(_getCodecDisplayName).join(' → ')}',
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _selectedCodecs.clear();
              _codecSelectionStatus.updateAll((key, value) => false);
            });
          },
          child: const Text('Clear All'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Save the selected codecs to the view model
            context
                .read<TelnyxClientViewModel>()
                .setPreferredCodecs(_selectedCodecs);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
