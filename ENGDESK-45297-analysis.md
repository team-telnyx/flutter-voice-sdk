# ENGDESK-45297: Flutter WebRTC Debug Report Missing Graphs Analysis

## Problem Statement
Flutter WebRTC debug reports were missing several graphs compared to iOS and Android implementations:
- Outbound audio level
- Outbound audio energy (totalAudioEnergy)
- Proper media-source stats linking

## Root Cause Analysis

### Flutter Implementation Issues
1. **Media-source stats processing**: Flutter was collecting media-source stats but not properly linking them to outbound-rtp stats in the debug report data structure
2. **Outbound audio level extraction**: Flutter was only extracting outbound audio level in call quality metrics, not in the main stats collection for socket reporting
3. **Missing totalAudioEnergy**: The totalAudioEnergy field was not being included in the debug report data structure
4. **Incomplete track linking**: Media-source data was not being properly linked to outbound-rtp stats for comprehensive reporting

### iOS Implementation (Working Correctly)
- Properly processes media-source stats with dedicated `extractOutboundAudioLevel()` method
- Links media-source data to outbound-rtp stats via the track property
- Includes totalAudioEnergy in track data
- Has comprehensive audio level extraction for both inbound and outbound

### Android Implementation (Working Correctly)
- Processes media-source stats and extracts outbound audio level directly
- Links media-source to outbound-rtp via mediaSourceId
- Includes outbound audio level in call quality metrics
- Proper candidate pair processing with local/remote candidate linking

## Solution Implemented

### 1. Enhanced Media-Source Stats Processing
```dart
// First pass: collect media-source stats
final Map<String, dynamic> mediaSourceStats = {};
for (var report in stats) {
  if (report.type == 'media-source') {
    final mediaSourceValues = report.values.cast<String, dynamic>();
    mediaSourceStats[report.id] = {
      ...mediaSourceValues,
      'id': report.id,
      'type': report.type,
      'timestamp': timestamp,
    };
    statsObject[report.id] = mediaSourceStats[report.id];
  }
}
```

### 2. Improved Outbound-RTP Processing with Media-Source Linking
```dart
case 'outbound-rtp':
  final outboundValues = report.values.cast<String, dynamic>();
  final mediaSourceId = outboundValues['mediaSourceId'] as String?;
  Map<String, dynamic>? linkedTrack;
  
  // Link with media-source if available
  if (mediaSourceId != null && mediaSourceStats.containsKey(mediaSourceId)) {
    linkedTrack = Map<String, dynamic>.from(mediaSourceStats[mediaSourceId]!);
  } else {
    linkedTrack = _constructTrack(outboundValues, timestamp);
  }
  
  audioOutboundStats.add({
    ...outboundValues,
    'timestamp': timestamp,
    'track': linkedTrack ?? {},
  });
```

### 3. Enhanced Call Quality Metrics Collection
```dart
// First pass: collect media-source stats for audio level extraction
final Map<String, Map<String, dynamic>> mediaSourceMap = {};
for (var report in stats) {
  if (report.type == 'media-source') {
    final mediaSourceValues = report.values.cast<String, dynamic>();
    if (mediaSourceValues['kind'] == 'audio') {
      mediaSourceMap[report.id] = mediaSourceValues;
      // Extract outbound audio level from media-source
      outboundAudioLevel =
          (mediaSourceValues['audioLevel'] as num?)?.toDouble() ?? 0.0;
    }
  }
}
```

### 4. Improved Track Construction
```dart
Map<String, dynamic>? _constructTrack(
  Map<String, dynamic> reportValues,
  double timestamp,
) {
  if (!reportValues.containsKey('mediaSourceId')) {
    return null;
  }

  return {
    'id': reportValues['mediaSourceId'],
    'timestamp': timestamp,
    'type': 'media-source',
    'kind': reportValues['kind'] ?? 'audio',
    'trackIdentifier': reportValues['trackIdentifier'],
    'audioLevel': reportValues['audioLevel'] ?? 0,
    'echoReturnLoss': reportValues['echoReturnLoss'],
    'echoReturnLossEnhancement': reportValues['echoReturnLossEnhancement'],
    'totalAudioEnergy': reportValues['totalAudioEnergy'] ?? 0,  // Now included
    'totalSamplesDuration': reportValues['totalSamplesDuration'] ?? 0,
  };
}
```

## Expected Results

After these changes, Flutter WebRTC debug reports should now include:

1. **Outbound audio level graphs** - Extracted from media-source stats and properly linked to outbound-rtp
2. **Outbound audio energy graphs** - totalAudioEnergy now included in track data
3. **Improved data consistency** - Better alignment with iOS and Android implementations
4. **Enhanced real-time metrics** - More accurate outbound audio level in call quality metrics

## Testing Recommendations

1. **Debug Report Verification**: Compare debug reports before and after the changes to verify new graphs appear
2. **Cross-Platform Consistency**: Verify that Flutter debug reports now match the structure and content of iOS/Android reports
3. **Real-time Metrics**: Test that outbound audio level is properly reflected in real-time call quality metrics
4. **Performance Impact**: Verify that the two-pass processing doesn't significantly impact performance

## Files Modified

- `packages/telnyx_webrtc/lib/utils/stats/webrtc_stats_reporter.dart`
  - Enhanced `_collectAndSendStats()` method with two-pass processing
  - Improved `_collectCallQualityMetrics()` method with better media-source handling
  - Updated `_constructTrack()` method to include totalAudioEnergy

## Compatibility

These changes are backward compatible and don't modify the public API. They only enhance the internal stats collection and reporting mechanisms to match the iOS and Android implementations.