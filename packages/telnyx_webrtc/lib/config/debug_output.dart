/// Debug output destination for call reports and diagnostics.
///
/// - [DebugOutput.socket] — stream reports over the existing WebSocket
///   connection (default).
/// - [DebugOutput.file] — write reports to a local file on the device
///   (mobile only; falls back to [DebugOutput.socket] on web).
enum DebugOutput {
  /// Stream reports over the WebSocket connection.
  socket,

  /// Write reports to a local file on the device.
  file,
}
