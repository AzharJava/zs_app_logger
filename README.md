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

### 1. Configuration

Initialize the logger in your `main.dart` before `runApp()`. Use `ZSLoggerConfig.configure` to set up the environment and behavior.

```dart
import 'package:app_logger/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ZSLoggerConfig.configure(
    environment: LoggerEnvironment.development, // .production, .qa
    showBugButton: true, // Toggle the debug banner
    enableLogging: true,
    enableStorage: true,
  );

  runApp(const MyApp());
}
```

### 2. UI Integration

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
| **`ZSAppLogger`** | The main entry point for logging. Contains methods like `logRequest`, `logResponse`, `logError`, and `log`. |
| **`ZSLoggerConfig`** | A singleton used to configure the logger's behavior (environment, visibility, storage). |
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
