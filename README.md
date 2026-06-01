# App Logger 🚀

A powerful, lightweight, and customizable logging package for Flutter applications. It provides structured logging for network requests, responses, errors, and general application logs with persistence support.

## Features ✨

- 🛠 **Structured Logging**: Track HTTP requests, responses, and errors with unique session IDs.
- 💾 **Persistence**: Logs are saved locally and persist across app restarts.
- 🐛 **Debug Banner**: A floating, tappable banner to quickly access the log viewer.
- 🖥 **Log Viewer**: A built-in screen to search, filter, and inspect detailed log entries.
- 🚨 **Auto Error Capture**: Automatically captures Flutter and Platform-level errors.
- ⚙️ **Environment Aware**: Different configurations for Development, QA, and Production.

---

## Getting Started 🏁

### 1. One-line setup (recommended)

Like Firebase Crashlytics — initialize once in `main` and automatically capture **Flutter errors**, **async errors**, and **zone errors**:

```dart
import 'package:zs_app_logger/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ZSLoggerConfig.bootstrap(
    environment: LoggerEnvironment.development, // .production, .qa
    showBugButton: true,
    startApp: () => runApp(const MyApp()),
  );
}
```

All crashes appear in the log viewer under sources like `Flutter Error`, `Async Error`, or `Zone Error`.

### 2. Manual setup (configure + runGuarded)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ZSLoggerConfig.configure(
    environment: LoggerEnvironment.development,
    captureErrors: true,        // Flutter + async errors (default: true)
    dumpErrorsToConsole: true,  // Also print in debug console
  );

  ZSLoggerConfig.runGuarded(() => runApp(const MyApp()));
}
```

### 3. Report errors manually

```dart
try {
  await riskyOperation();
} catch (e, stack) {
  ZSAppLogger.captureException(e, stack, source: 'Checkout', reason: 'Payment failed');
}
```

### 4. Forward to Firebase / Sentry

Use `onErrorReported` in `bootstrap` or `configure`, or register multiple reporters:

```dart
await ZSLoggerConfig.bootstrap(
  environment: LoggerEnvironment.production,
  startApp: () => runApp(const MyApp()),
  onErrorReported: (report) {
    // Firebase Crashlytics example:
    // FirebaseCrashlytics.instance.recordError(
    //   report.error,
    //   report.stack,
    //   reason: report.source,
    // );
    // Sentry example:
    // Sentry.captureException(report.error, stackTrace: report.stack);
  },
);

// Or add later:
ZSAppLogger.addErrorReporter((report) { /* ... */ });
```

### 5. Crash filter in log viewer

Open the log screen and tap the **Crashes** filter chip to see only Flutter/async/zone errors. Crash logs are highlighted in orange and counted separately in the stats bar.

### 6. UI Integration

Wrap your application or specific screens with the `DebugBanner` to provide easy access to logs.

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(child: DebugBanner()),
            ),
          ],
        );
      },
      home: const HomeScreen(),
    );
  }
}
```

---

## Usage Examples 💡

### Logging Network Requests

The logger uses a session-based approach to group related request and response logs.

```dart
// 1. Start tracking a request
final sessionId = ZSAppLogger.logRequest(
  method: 'POST',
  uri: 'https://api.example.com/v1/login',
  headers: {'Content-Type': 'application/json'},
  body: {'email': 'user@example.com'},
);

try {
  // Perform your network call...
  final response = await myHttpClient.post(...);

  // 2. Log the successful response
  ZSAppLogger.logResponse(
    id: sessionId,
    statusCode: 200,
    uri: 'https://api.example.com/v1/login',
    data: response.body,
  );
} catch (e) {
  // 3. Log errors if the request fails
  ZSAppLogger.logError(
    id: sessionId,
    statusCode: 500,
    uri: 'https://api.example.com/v1/login',
    errorMessage: e.toString(),
    errorType: 'NetworkException',
  );
}
```

### Simple Logging

For general information or debugging messages:

```dart
ZSAppLogger.log("User clicked on the login button");
```

---

## Key Components 🔑

| Keyword / Class | Description |
| :--- | :--- |
| **`ZSAppLogger`** | The main entry point for logging. Contains `logRequest`, `logResponse`, `logError`, `captureException`, and `log`. |
| **`ZSLoggerConfig`** | Configure the logger. Use `bootstrap()` for one-call init + error capture, or `configure()` + `runGuarded()`. |
| **`ZSCrashCapture`** | Low-level global error handlers (usually used via `ZSLoggerConfig`). |
| **`ZSErrorCaptureOptions`** | Toggle Flutter/async error capture and console dumping. |
| **`ZSCrashReport`** | Error payload passed to `onErrorReported` / `ZSErrorReporter`. |
| **`ZSErrorReporter`** | Callback type for forwarding errors to external services. |
| **`FilterStatus.crash`** | Log viewer filter for app crashes only. |
| **`DebugBanner`** | A widget that shows a "Tap to View Logs" banner. It respects the `ZSLoggerConfig` visibility rules. |
| **`LogScreen`** | The UI component that displays the list of all captured logs. |
| **`LoggerEnvironment`**| Enum containing `production`, `development`, and `qa` to control logger sensitivity. |
| **`ZSLogType`** | Enum defining the type of log: `request`, `response`, `error`, or `info`. |

---

## Manual Log Management 🧹

You can manually clear or refresh logs using the following methods:

```dart
// Clear all logs from memory and storage
ZSAppLogger.clear();

// Reload logs from local storage
await ZSAppLogger.refresh();

// Delete a specific log group by ID
ZSAppLogger.deleteLogGroup(sessionId);
```

---

## Advanced Configuration 🛠

### Restricting Access by Device ID

In production, you might want to show the logs only to specific developers. You can restrict the `DebugBanner` to specific device IDs:

```dart
await ZSLoggerConfig.configure(
  environment: LoggerEnvironment.production,
  showBugButton: true,
  allowedDeviceIds: ['YOUR_DEVICE_ID_1', 'YOUR_DEVICE_ID_2'],
);
```

---

Developed with ❤️ for **Piston Fuel**.
