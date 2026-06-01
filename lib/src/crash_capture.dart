import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_logger.dart';
import 'models/request_log_group.dart';

/// Payload sent to [ZSErrorReporter] callbacks (Firebase, Sentry, etc.).
class ZSCrashReport {
  final Object error;
  final StackTrace? stack;
  final String source;
  final String? reason;
  final DateTime timestamp;

  const ZSCrashReport({
    required this.error,
    required this.stack,
    required this.source,
    this.reason,
    required this.timestamp,
  });
}

/// Forward captured errors to Firebase Crashlytics, Sentry, or your backend.
typedef ZSErrorReporter = void Function(ZSCrashReport report);

/// Options for automatic crash and error capture.
class ZSErrorCaptureOptions {
  /// Capture Flutter framework errors (build/layout/paint, etc.).
  final bool captureFlutterErrors;

  /// Capture uncaught async errors via [PlatformDispatcher.onError].
  final bool capturePlatformErrors;

  /// Print errors to console in debug mode (in addition to logging).
  final bool dumpToConsoleInDebug;

  const ZSErrorCaptureOptions({
    this.captureFlutterErrors = true,
    this.capturePlatformErrors = true,
    this.dumpToConsoleInDebug = true,
  });

  static const ZSErrorCaptureOptions all = ZSErrorCaptureOptions();

  static const ZSErrorCaptureOptions none = ZSErrorCaptureOptions(
    captureFlutterErrors: false,
    capturePlatformErrors: false,
    dumpToConsoleInDebug: false,
  );
}

/// Installs global error handlers and routes them to [ZSAppLogger].
class ZSCrashCapture {
  static const Set<String> crashSources = {
    'Flutter Error',
    'Async Error',
    'Zone Error',
    'Uncaught Error',
    'Platform Error', // legacy
  };

  /// Whether a log group is an app crash / uncaught exception.
  static bool isCrashGroup(ZSRequestLogGroup group) {
    if (group.isCrash) return true;
    return group.statusCode == 0 &&
        group.isError &&
        crashSources.contains(group.uri);
  }

  static bool _installed = false;
  static FlutterExceptionHandler? _previousFlutterOnError;
  static bool Function(Object, StackTrace)? _previousPlatformOnError;

  static void install({
    ZSErrorCaptureOptions options = ZSErrorCaptureOptions.all,
  }) {
    if (_installed) return;
    _installed = true;

    if (options.captureFlutterErrors) {
      _previousFlutterOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        ZSAppLogger.captureException(
          details.exception,
          details.stack,
          source: 'Flutter Error',
          flutterDetails: details,
        );
        if (options.dumpToConsoleInDebug && kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        }
        _previousFlutterOnError?.call(details);
      };
    }

    if (options.capturePlatformErrors) {
      _previousPlatformOnError = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (error, stack) {
        ZSAppLogger.captureException(
          error,
          stack,
          source: 'Async Error',
        );
        if (options.dumpToConsoleInDebug && kDebugMode) {
          debugPrint('Async Error: $error\n$stack');
        }
        return _previousPlatformOnError?.call(error, stack) ?? true;
      };
    }
  }

  /// Wraps [body] in [runZonedGuarded] to catch errors that escape the widget tree.
  static void runGuarded(
    void Function() body, {
    void Function(Object error, StackTrace stack)? onUncaughtError,
  }) {
    runZonedGuarded(
      body,
      (error, stack) {
        ZSAppLogger.captureException(error, stack, source: 'Zone Error');
        onUncaughtError?.call(error, stack);
      },
    );
  }
}
