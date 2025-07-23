import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BackgroundDetector extends StatefulWidget {
  static BackgroundDetector? _instance;

  static bool _skipWeb = false;

  static bool get skipWeb => _skipWeb;
  static set skipWeb(bool value) => _skipWeb = value;

  factory BackgroundDetector({
    Key? key,
    bool skipWeb = false,
    required Widget child,
    void Function(AppLifecycleState)? onLifecycleEvent,
  }) {
    _skipWeb = skipWeb;
    _instance ??= BackgroundDetector._internal(
      key: key,
      onLifecycleEvent: onLifecycleEvent,
      child: child,
    );
    return _instance!;
  }

  const BackgroundDetector._internal({
    Key? key,
    required this.child,
    this.onLifecycleEvent,
  }) : super(key: key);

  final Widget child;

  /// Callback to invoke on lifecycle events (if not ignored).
  final void Function(AppLifecycleState)? onLifecycleEvent;

  // --------------------------------------------------------------------------
  //             IGNORE / IGNOREWHILE LOGIC (STATIC)
  // --------------------------------------------------------------------------
  static bool _ignoreLifecycleEvents = false;

  /// Whether to globally ignore lifecycle events
  static bool get ignore => _ignoreLifecycleEvents;

  static set ignore(bool value) => _ignoreLifecycleEvents = value;

  /// Temporarily ignore lifecycle events during [action].
  /// Reverts to the old ignore state afterward.
  static Future<T> ignoreWhile<T>(FutureOr<T> Function() action) async {
    final wasIgnoring = _ignoreLifecycleEvents;
    _ignoreLifecycleEvents = true;
    try {
      return await action();
    } finally {
      _ignoreLifecycleEvents = wasIgnoring;
    }
  }

  @override
  State<BackgroundDetector> createState() => _BackgroundDetectorState();
}

class _BackgroundDetectorState extends State<BackgroundDetector>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (BackgroundDetector.skipWeb == true && kIsWeb) return;
    // Only emit if NOT ignoring
    if (!BackgroundDetector.ignore) {
      widget.onLifecycleEvent?.call(state);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
