enum WebRTCStatsEvent {
  addConnection('addConnection'),
  stats('stats'),
  onIceCandidate('onicecandidate'),
  onTrack('ontrack'),
  onSignalingStateChange('onsignalingstatechange'),
  onIceConnectionStateChange('oniceconnectionstatechange'),
  onIceGatheringStateChange('onicegatheringstatechange'),
  onIceCandidateError('onicecandidateerror'),
  onConnectionStateChange('onconnectionstatechange'),
  onNegotiationNeeded('onnegotiationneeded'),
  onDataChannel('ondatachannel'),
  getUserMedia('getUserMedia'),
  mute('mute'),
  unmute('unmute'),
  overconstrained('overconstrained'),
  ended('ended');

  const WebRTCStatsEvent(this.value);
  final String value;
}
