import 'package:telnyx_webrtc/utils/logging/log_collector.dart';

/// Owns the app's [LogCollector] so the diagnostics view has something to read.
///
/// The SDK ships [LogCollector] and a global slot for it, but never installs
/// one — without this, `getLogs()` would always be empty. We install ours at
/// app start so the buffer is already populated by the time someone opens the
/// diagnostics sheet.
///
/// The global slot is shared: `CallReportCollector.configureLogCollector`
/// replaces it when a call begins, which would silently orphan ours and freeze
/// the log panel mid-call. [ensureInstalled] re-claims the slot, and the view
/// calls it on every refresh.
class DiagnosticsLogService {
  DiagnosticsLogService._();

  /// The single shared instance.
  static final DiagnosticsLogService instance = DiagnosticsLogService._();

  /// Keep a bounded buffer — this lives for the whole app session.
  static const int _maxEntries = 1000;

  LogCollector? _collector;

  /// The collector this service owns, if [install] has run.
  LogCollector? get collector => _collector;

  /// Whether our collector is the one currently receiving SDK logs.
  ///
  /// False means something else claimed the global slot, so the buffer is
  /// stale. Surfaced in the UI rather than hidden, because a silently frozen
  /// log panel is worse than one that says it stopped.
  bool get isActiveGlobally =>
      _collector != null && identical(getGlobalLogCollector(), _collector);

  /// Creates the collector and claims the global slot. Safe to call twice.
  void install() {
    _collector ??= LogCollector(maxEntries: _maxEntries);
    ensureInstalled();
  }

  /// Re-claims the global slot if another component took it.
  void ensureInstalled() {
    final collector = _collector;
    if (collector == null) {
      return;
    }
    if (!identical(getGlobalLogCollector(), collector)) {
      setGlobalLogCollector(collector);
    }
    if (!collector.isActive) {
      collector.start();
    }
  }

  /// The collected entries, newest last. Empty if [install] has not run.
  List<LogEntry> getLogs() => _collector?.getLogs() ?? const [];

  /// Drops every buffered entry.
  void clear() => _collector?.clear();
}
