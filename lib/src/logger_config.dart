import 'app_logger.dart';

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

  /// Initialize configuration with environment
  /// Call this once in main.dart - it will also initialize AppLogger
  static Future<void> configure({
    required LoggerEnvironment environment,
    bool? showBugButton,
    bool? enableLogging,
    bool? enableStorage,
    List<String>? allowedDeviceIds,
  }) async {
    await ZSAppLogger.init();
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
}
