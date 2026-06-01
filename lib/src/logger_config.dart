import 'app_logger.dart';
import 'crash_capture.dart';

/// Environment types for logger configuration
enum LoggerEnvironment {
  production,
  development,
  qa,
}

/// Singleton configuration class for AppLogger
/// Configure once in main.dart and use throughout the app
class ZSLoggerConfig {
  static ZSLoggerConfig? _instance;
  late LoggerEnvironment _environment;
  bool _showBugButton = false;
  bool _enableLogging = true;
  bool _enableStorage = true;
  List<String>? _allowedDeviceIds;

  ZSLoggerConfig._internal();

  /// Get the singleton instance
  factory ZSLoggerConfig() {
    _instance ??= ZSLoggerConfig._internal();
    return _instance!;
  }

  /// Initialize configuration with environment.
  /// Call once in main.dart — also installs Flutter/async error capture.
  static Future<void> configure({
    required LoggerEnvironment environment,
    bool? showBugButton,
    bool? enableLogging,
    bool? enableStorage,
    List<String>? allowedDeviceIds,
    bool captureErrors = true,
    bool dumpErrorsToConsole = true,
    ZSErrorReporter? onErrorReported,
  }) async {
    if (onErrorReported != null) {
      ZSAppLogger.addErrorReporter(onErrorReported);
    }
    final resolvedEnableStorage = enableStorage ?? true;
    await ZSAppLogger.init(
      saveToLocalStorage: resolvedEnableStorage,
      errorCapture: captureErrors
          ? ZSErrorCaptureOptions(
              dumpToConsoleInDebug: dumpErrorsToConsole,
            )
          : ZSErrorCaptureOptions.none,
    );
    ZSAppLogger.log("Environment is : $environment");
    final config = ZSLoggerConfig();
    config._environment = environment;
    config._allowedDeviceIds = allowedDeviceIds;
    // Set default values based on environment
    switch (environment) {
      case LoggerEnvironment.production:
        config._showBugButton =
            showBugButton ?? false; // Hidden by default in production
        config._enableLogging =
            enableLogging ?? true; // Still log but don't show UI
        config._enableStorage = enableStorage ?? true;
        break;
      case LoggerEnvironment.development:
        config._showBugButton =
            showBugButton ?? true; // Shown by default in dev
        config._enableLogging = enableLogging ?? true;
        config._enableStorage = enableStorage ?? true;
        break;
      case LoggerEnvironment.qa:
        config._showBugButton = showBugButton ?? true; // Shown by default in QA
        config._enableLogging = enableLogging ?? true;
        config._enableStorage = enableStorage ?? true;
        break;
    }
  }

  /// Get current environment
  LoggerEnvironment get environment => _environment;

  /// Check if bug button should be shown
  bool get showBugButton => _showBugButton;

  /// Check if logging is enabled
  bool get enableLogging => _enableLogging;

  /// Check if storage is enabled
  bool get enableStorage => _enableStorage;

  /// Check if in production
  bool get isProduction => _environment == LoggerEnvironment.production;

  /// Check if in development
  bool get isDevelopment => _environment == LoggerEnvironment.development;

  /// Check if in QA
  bool get isQa => _environment == LoggerEnvironment.qa;

  /// Get allowed device IDs
  List<String>? get allowedDeviceIds => _allowedDeviceIds;

  /// Run your app inside a guarded zone so zone-level errors are logged too.
  /// Call after [configure]:
  ///
  /// ```dart
  /// await ZSLoggerConfig.configure(...);
  /// ZSLoggerConfig.runGuarded(() => runApp(const MyApp()));
  /// ```
  static void runGuarded(
    void Function() startApp, {
    void Function(Object error, StackTrace stack)? onUncaughtError,
  }) {
    ZSCrashCapture.runGuarded(startApp, onUncaughtError: onUncaughtError);
  }

  /// One-call setup: configure logger + run app with full error capture.
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await ZSLoggerConfig.bootstrap(
  ///     environment: LoggerEnvironment.development,
  ///     startApp: () => runApp(const MyApp()),
  ///   );
  /// }
  /// ```
  static Future<void> bootstrap({
    required LoggerEnvironment environment,
    required void Function() startApp,
    bool? showBugButton,
    bool? enableLogging,
    bool? enableStorage,
    List<String>? allowedDeviceIds,
    bool captureErrors = true,
    bool dumpErrorsToConsole = true,
    ZSErrorReporter? onErrorReported,
    void Function(Object error, StackTrace stack)? onUncaughtError,
  }) async {
    await configure(
      environment: environment,
      showBugButton: showBugButton,
      enableLogging: enableLogging,
      enableStorage: enableStorage,
      allowedDeviceIds: allowedDeviceIds,
      captureErrors: captureErrors,
      dumpErrorsToConsole: dumpErrorsToConsole,
      onErrorReported: onErrorReported,
    );
    runGuarded(startApp, onUncaughtError: onUncaughtError);
  }
}
