/// Represents an audio codec with its properties
class AudioCodec {
  /// The number of audio channels (e.g., 1 for mono, 2 for stereo)
  final int? channels;

  /// The clock rate in Hz (e.g., 48000, 8000)
  final int? clockRate;

  /// The MIME type of the codec (e.g., "audio/opus", "audio/PCMU")
  final String? mimeType;

  /// The SDP format parameters line
  final String? sdpFmtpLine;

  /// Creates an AudioCodec instance
  const AudioCodec({
    this.channels,
    this.clockRate,
    this.mimeType,
    this.sdpFmtpLine,
  });

  /// Creates an AudioCodec from JSON
  factory AudioCodec.fromJson(Map<String, dynamic> json) {
    return AudioCodec(
      channels: json['channels'] as int?,
      clockRate: json['clockRate'] as int?,
      mimeType: json['mimeType'] as String?,
      sdpFmtpLine: json['sdpFmtpLine'] as String?,
    );
  }

  /// Converts the AudioCodec to JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (channels != null) data['channels'] = channels;
    if (clockRate != null) data['clockRate'] = clockRate;
    if (mimeType != null) data['mimeType'] = mimeType;
    if (sdpFmtpLine != null) data['sdpFmtpLine'] = sdpFmtpLine;
    return data;
  }

  @override
  String toString() {
    return 'AudioCodec(mimeType: $mimeType, clockRate: $clockRate, channels: $channels, sdpFmtpLine: $sdpFmtpLine)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioCodec &&
        other.channels == channels &&
        other.clockRate == clockRate &&
        other.mimeType == mimeType &&
        other.sdpFmtpLine == sdpFmtpLine;
  }

  @override
  int get hashCode {
    return Object.hash(channels, clockRate, mimeType, sdpFmtpLine);
  }
}
