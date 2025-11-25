/*
 * Copyright © 2025 Telnyx LLC. All rights reserved.
 */

/// Represents audio processing constraints for WebRTC media streams.
/// These constraints control audio processing features that improve call quality
/// by reducing echo, background noise, and normalizing audio levels.
///
/// Aligns with the W3C MediaTrackConstraints specification for audio.
///
/// See: https://w3c.github.io/mediacapture-main/getusermedia.html#def-constraint-echoCancellation
/// See: https://w3c.github.io/mediacapture-main/getusermedia.html#dfn-noisesuppression
/// See: https://w3c.github.io/mediacapture-main/getusermedia.html#dfn-autogaincontrol
class AudioConstraints {
  /// Enable/disable echo cancellation. When enabled, removes acoustic
  /// echo caused by audio feedback between microphone and speaker. Default: true
  final bool echoCancellation;

  /// Enable/disable noise suppression. When enabled, reduces background
  /// noise to improve voice clarity. Default: true
  final bool noiseSuppression;

  /// Enable/disable automatic gain control. When enabled, automatically
  /// adjusts microphone gain to normalize audio levels. Default: true
  final bool autoGainControl;

  /// Creates a new AudioConstraints instance with the specified values.
  /// All parameters default to true to enable all audio processing features.
  const AudioConstraints({
    this.echoCancellation = true,
    this.noiseSuppression = true,
    this.autoGainControl = true,
  });

  /// Creates an AudioConstraints instance with all features disabled.
  factory AudioConstraints.disabled() {
    return const AudioConstraints(
      echoCancellation: false,
      noiseSuppression: false,
      autoGainControl: false,
    );
  }

  /// Creates an AudioConstraints instance with all features enabled.
  factory AudioConstraints.enabled() {
    return const AudioConstraints(
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
    );
  }

  /// Creates a copy of this AudioConstraints with the specified values replaced.
  AudioConstraints copyWith({
    bool? echoCancellation,
    bool? noiseSuppression,
    bool? autoGainControl,
  }) {
    return AudioConstraints(
      echoCancellation: echoCancellation ?? this.echoCancellation,
      noiseSuppression: noiseSuppression ?? this.noiseSuppression,
      autoGainControl: autoGainControl ?? this.autoGainControl,
    );
  }

  /// Converts the AudioConstraints to a Map suitable for WebRTC configuration.
  Map<String, dynamic> toMap() {
    return {
      'echoCancellation': echoCancellation,
      'noiseSuppression': noiseSuppression,
      'autoGainControl': autoGainControl,
    };
  }

  /// Creates an AudioConstraints instance from a Map.
  factory AudioConstraints.fromMap(Map<String, dynamic> map) {
    if (map['echoCancellation'] != null && map['echoCancellation'] is! bool) {
      throw const FormatException('echoCancellation must be a boolean');
    }
    if (map['noiseSuppression'] != null && map['noiseSuppression'] is! bool) {
      throw const FormatException('noiseSuppression must be a boolean');
    }
    if (map['autoGainControl'] != null && map['autoGainControl'] is! bool) {
      throw const FormatException('autoGainControl must be a boolean');
    }

    return AudioConstraints(
      echoCancellation: map['echoCancellation'] as bool? ?? true,
      noiseSuppression: map['noiseSuppression'] as bool? ?? true,
      autoGainControl: map['autoGainControl'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioConstraints &&
        other.echoCancellation == echoCancellation &&
        other.noiseSuppression == noiseSuppression &&
        other.autoGainControl == autoGainControl;
  }

  @override
  int get hashCode {
    return echoCancellation.hashCode ^
        noiseSuppression.hashCode ^
        autoGainControl.hashCode;
  }

  @override
  String toString() {
    return 'AudioConstraints('
        'echoCancellation: $echoCancellation, '
        'noiseSuppression: $noiseSuppression, '
        'autoGainControl: $autoGainControl)';
  }
}