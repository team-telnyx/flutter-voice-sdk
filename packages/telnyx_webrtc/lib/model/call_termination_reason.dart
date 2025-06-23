/// Data class to hold detailed reasons for call termination.
/// All fields are optional as they may not always be available.
class CallTerminationReason {
  /// General cause description (e.g., "CALL_REJECTED").
  final String? cause;

  /// Numerical code for the cause (e.g., 21).
  final int? causeCode;

  /// SIP response code (e.g., 403).
  final int? sipCode;

  /// SIP reason phrase (e.g., "Dialed number is not included in whitelisted countries").
  final String? sipReason;

  /// Creates a new [CallTerminationReason] instance.
  const CallTerminationReason({
    this.cause,
    this.causeCode,
    this.sipCode,
    this.sipReason,
  });

  /// Creates a string representation of the termination reason.
  @override
  String toString() {
    final List<String> parts = [];

    if (sipCode != null) {
      parts.add('SIP $sipCode');
    }

    if (sipReason != null && sipReason!.isNotEmpty) {
      parts.add(sipReason!);
    } else if (cause != null && cause!.isNotEmpty) {
      parts.add(cause!);
    }

    if (parts.isEmpty) {
      return 'Unknown reason';
    }

    return parts.join(': ');
  }
}
