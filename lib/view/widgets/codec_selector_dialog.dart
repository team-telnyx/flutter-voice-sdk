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
  List<AudioCodec> _availableCodecs = [];
  List<AudioCodec> _selectedCodecs = [];
  Map<String, bool> _codecSelectionStatus = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCodecs();
  }

  Future<void> _loadCodecs() async {
    final viewModel = context.read<TelnyxClientViewModel>();

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load supported codecs from the SDK if not already loaded
      if (viewModel.supportedCodecs.isEmpty) {
        await viewModel.loadSupportedCodecs();
      }

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

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load codecs: $e';
      });
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
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading supported codecs...',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCodecs,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : Column(
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
                                unselectedLabelColor:
                                    theme.textTheme.bodyMedium?.color,
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
                                            _codecSelectionStatus[codecKey] ??
                                                false;

                                        return CheckboxListTile(
                                          title:
                                              Text(_getCodecDisplayName(codec)),
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
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
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
                                              final codec =
                                                  _selectedCodecs[index];
                                              return ListTile(
                                                key: ValueKey(
                                                  '${codec.mimeType}_${codec.clockRate}',
                                                ),
                                                leading: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      '${index + 1}',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            theme.primaryColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                title: Text(
                                                  _getCodecDisplayName(codec),
                                                ),
                                                trailing: const Icon(
                                                  Icons.drag_handle,
                                                ),
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
