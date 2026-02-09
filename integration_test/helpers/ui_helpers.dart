import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'test_config.dart';

/// Extension for common UI actions with retry logic
extension UIHelpers on PatrolIntegrationTester {
  /// Tap with retry - handles cases where element might not be ready
  Future<void> tapWithRetry(
    Finder finder, {
    int maxRetries = TestConfig.maxRetries,
    Duration retryDelay = TestConfig.retryDelay,
    String? description,
  }) async {
    Exception? lastError;

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        await tester.tap(finder);
        await pumpAndSettle();
        return;
      } catch (e) {
        lastError = e as Exception;
        if (attempt < maxRetries - 1) {
          await Future.delayed(retryDelay);
          await pump();
        }
      }
    }

    throw TestFailure(
      'Failed to tap ${description ?? finder.toString()} '
      'after $maxRetries attempts: $lastError',
    );
  }

  /// Tap text with retry
  Future<void> tapTextWithRetry(String text) async {
    await tapWithRetry(find.text(text), description: 'text "$text"');
  }

  /// Tap icon with retry
  Future<void> tapIconWithRetry(IconData icon) async {
    await tapWithRetry(find.byIcon(icon), description: 'icon $icon');
  }

  /// Tap widget type with retry
  Future<void> tapTypeWithRetry<T extends Widget>() async {
    await tapWithRetry(find.byType(T), description: 'type $T');
  }

  /// Enter text in field with retry
  Future<void> enterTextWithRetry(
    int fieldIndex,
    String text, {
    int maxRetries = TestConfig.maxRetries,
  }) async {
    Exception? lastError;

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(fieldIndex), text);
        await pumpAndSettle();
        return;
      } catch (e) {
        lastError = e as Exception;
        if (attempt < maxRetries - 1) {
          await Future.delayed(TestConfig.retryDelay);
          await pump();
        }
      }
    }

    throw TestFailure(
      'Failed to enter text in field $fieldIndex after $maxRetries attempts: $lastError',
    );
  }

  /// Grant permissions if requested
  Future<void> grantPermissionsIfNeeded() async {
    try {
      await native.grantPermissionWhenInUse();
    } catch (_) {
      // Permission dialog might not appear - that's okay
    }
  }

  /// Check if element exists without throwing
  bool exists(Finder finder) {
    return finder.evaluate().isNotEmpty;
  }

  /// Tap if exists, otherwise skip
  Future<bool> tapIfExists(Finder finder) async {
    if (exists(finder)) {
      await tester.tap(finder);
      await pumpAndSettle();
      return true;
    }
    return false;
  }

  /// Tap text if exists
  Future<bool> tapTextIfExists(String text) async {
    return tapIfExists(find.text(text));
  }
}

/// Custom error handler to ignore render overflow errors
void ignoreOverflowErrors(
  FlutterErrorDetails details, {
  bool forceReport = false,
}) {
  final exception = details.exception;
  if (exception is FlutterError) {
    final isOverflow = exception.diagnostics.any(
      (e) => e.value.toString().contains('A RenderFlex overflowed by'),
    );
    final isAssetError = exception.diagnostics.any(
      (e) => e.value.toString().contains('Unable to load asset'),
    );

    if (isOverflow || isAssetError) {
      debugPrint('Ignored error: ${exception.toString()}');
      return;
    }
  }

  FlutterError.dumpErrorToConsole(details, forceReport: forceReport);
}

// Note: For setup/teardown, use the pattern shown in individual tests:
// final originalOnError = FlutterError.onError;
// FlutterError.onError = ignoreOverflowErrors;
// addTearDown(() => FlutterError.onError = originalOnError);
