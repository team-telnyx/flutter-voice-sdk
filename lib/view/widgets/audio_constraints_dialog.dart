import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_webrtc/model/audio_constraints.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';

class AudioConstraintsDialog extends StatefulWidget {
  const AudioConstraintsDialog({Key? key}) : super(key: key);

  @override
  State<AudioConstraintsDialog> createState() => _AudioConstraintsDialogState();
}

class _AudioConstraintsDialogState extends State<AudioConstraintsDialog> {
  late bool _echoCancellation;
  late bool _noiseSuppression;
  late bool _autoGainControl;

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<TelnyxClientViewModel>();
    final currentConstraints = viewModel.audioConstraints;
    
    _echoCancellation = currentConstraints.echoCancellation;
    _noiseSuppression = currentConstraints.noiseSuppression;
    _autoGainControl = currentConstraints.autoGainControl;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Audio Constraints'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Configure audio processing features for WebRTC calls:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildSwitchTile(
            'Echo Cancellation',
            'Reduces echo from audio feedback',
            _echoCancellation,
            (value) => setState(() => _echoCancellation = value),
          ),
          _buildSwitchTile(
            'Noise Suppression',
            'Reduces background noise',
            _noiseSuppression,
            (value) => setState(() => _noiseSuppression = value),
          ),
          _buildSwitchTile(
            'Auto Gain Control',
            'Automatically adjusts microphone volume',
            _autoGainControl,
            (value) => setState(() => _autoGainControl = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _resetToDefaults,
          child: const Text('Reset'),
        ),
        ElevatedButton(
          onPressed: _saveConstraints,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        value: value,
        onChanged: onChanged,
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  void _resetToDefaults() {
    setState(() {
      _echoCancellation = true;
      _noiseSuppression = true;
      _autoGainControl = true;
    });
  }

  void _saveConstraints() {
    final constraints = AudioConstraints(
      echoCancellation: _echoCancellation,
      noiseSuppression: _noiseSuppression,
      autoGainControl: _autoGainControl,
    );

    final viewModel = context.read<TelnyxClientViewModel>();
    viewModel.setAudioConstraints(constraints);

    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audio constraints updated'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}