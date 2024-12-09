enum WebRTCStatsTag {
  peer('peer'),
  stats('stats'),
  connection('connection'),
  track('track'),
  dataChannel('datachannel'),
  getUserMedia('getUserMedia');

  const WebRTCStatsTag(this.value);
  final String value;
}
