import 'package:flutter/foundation.dart';

import 'models/log_entry.dart';
import 'models/request_log_group.dart';
import 'storage_manager.dart';

class ZSAppLogger {
  static final List<ZSRequestLogGroup> _logGroups = [];
  // Store active request groups by ID for concurrency support
  static final Map<String, ZSRequestLogGroup> _activeGroups = {};
  // Store stopwatches for accurate duration measurement
  static final Map<String, Stopwatch> _activeStopwatches = {};
  // Map to store recent requests by URI for method lookup
  static final Map<String, String> _uriMethodMap = {};
  static const int _maxUriMethodEntries = 100;

  static Future<void> init() async {
    await ZSStorageManager.init();
    final storedGroups = await ZSStorageManager.loadLogGroups();
    _logGroups.addAll(storedGroups);

    FlutterError.onError = (FlutterErrorDetails details) {
      logError(
        statusCode: 0,
        uri: 'Flutter Error',
        errorMessage: details.exceptionAsString(),
      );
      if (kDebugMode) FlutterError.dumpErrorToConsole(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      logError(
        statusCode: 0,
        uri: 'Platform Error',
        errorMessage: "$error\n$stack",
      );
      return true;
      //complete the code
    };
    debugPrint("🔥 AppLogger initialized");
  }

  /// Start a new request log group and return its ID
  static String startRequest({
    required String method,
    required String uri,
  }) {
    final id = "${DateTime.now().millisecondsSinceEpoch}_${uri.hashCode}";
    final group = ZSRequestLogGroup(
      id: id,
      method: method,
      uri: uri,
      timestamp: DateTime.now(),
      entries: [],
    );
    _activeGroups[id] = group;
    _activeStopwatches[id] = Stopwatch()..start();
    return id;
  }

  /// Add a log entry to the current request group
  static void addLogEntry(String message, ZSLogType type,
      {bool autoClose = false}) {
    final entry = ZSLogEntry(
      message: message,
      timestamp: DateTime.now(),
      type: type,
    );

    // If no group is provided/found, we could use the "last" active one as fallback
    // but it's better to be explicit or create a new one.
    // For standalone logs, we use a fallback ID 'standalone_TIMESTAMP'
    final groupId = "${DateTime.now().millisecondsSinceEpoch}_standalone";
    final group = ZSRequestLogGroup(
      id: groupId,
      method: 'INFO',
      uri: 'Application Log',
      timestamp: DateTime.now(),
      entries: [entry],
    );

    // Standalone logs are added directly to the list
    _logGroups.add(group);
    ZSStorageManager.saveLogGroups(_logGroups);

    if (kDebugMode) print(entry.formattedMessage);
  }

  /// Internal helper to add log entry to a specific group
  static void addLogEntryToGroup(String message, ZSLogType type, String id) {
    final entry = ZSLogEntry(
      message: message,
      timestamp: DateTime.now(),
      type: type,
    );
    final group = _activeGroups[id];
    if (group != null) {
      group.entries.add(entry);
    }
  }

  /// End a request group and save it
  static void endRequest(String id,
      {int? statusCode, bool isError = false, int? responseSize}) {
    final group = _activeGroups.remove(id);
    final stopwatch = _activeStopwatches.remove(id);

    if (group != null) {
      stopwatch?.stop();
      final duration = stopwatch?.elapsedMilliseconds;

      final updatedGroup = ZSRequestLogGroup(
        id: group.id,
        method: group.method,
        uri: group.uri,
        timestamp: group.timestamp,
        entries: group.entries,
        statusCode: statusCode ?? group.statusCode,
        isError: isError,
        duration: duration,
        responseSize: responseSize,
      );

      _logGroups.add(updatedGroup);
      ZSStorageManager.saveLogGroups(_logGroups);
    }
  }

  /// Log a request and return a session ID
  static String logRequest({
    required String method,
    required String uri,
    Map<String, dynamic>? headers,
    dynamic body,
    String? token,
  }) {
    // Store the method for this URI in case we need it later (fallback logic)
    _uriMethodMap[uri] = method;
    if (_uriMethodMap.length > _maxUriMethodEntries) {
      final keysToRemove = _uriMethodMap.keys
          .take(_uriMethodMap.length - _maxUriMethodEntries)
          .toList();
      for (final key in keysToRemove) {
        _uriMethodMap.remove(key);
      }
    }

    final id = startRequest(method: method, uri: uri);
    addLogEntryToGroup("➡️ [REQUEST] $method $uri", ZSLogType.request, id);
    if (headers != null && headers.isNotEmpty) {
      addLogEntryToGroup("Headers: $headers", ZSLogType.request, id);
    }
    if (body != null) {
      addLogEntryToGroup("Body: $body", ZSLogType.request, id);
    }
    if (token != null) {
      addLogEntryToGroup("Token: $token", ZSLogType.request, id);
    }
    return id;
  }

  /// Log a response using a session ID
  static void logResponse({
    required int statusCode,
    required String uri,
    dynamic data,
    String? id,
  }) {
    String sessionId = id ?? "";

    // Fallback if no ID — try to find an active request for this URI
    if (sessionId.isEmpty) {
      for (var entry in _activeGroups.entries) {
        if (entry.value.uri == uri) {
          sessionId = entry.key;
          break;
        }
      }
    }

    // If still no ID, create a standalone log group (will be inaccurate for duration)
    if (sessionId.isEmpty) {
      String method = _uriMethodMap[uri] ?? 'GET';
      sessionId = startRequest(method: method, uri: uri);
      _uriMethodMap.remove(uri);
    }

    // Calculate response size
    int? responseSize;
    if (data != null) {
      if (data is String) {
        responseSize = data.length;
      } else {
        try {
          responseSize = data.toString().length;
        } catch (_) {}
      }
    }

    addLogEntryToGroup("✅ [RESPONSE] StatusCode: $statusCode $uri",
        ZSLogType.response, sessionId);
    if (data != null) {
      addLogEntryToGroup("Response Data: $data", ZSLogType.response, sessionId);
    }

    endRequest(sessionId, statusCode: statusCode, responseSize: responseSize);
  }

  /// Log an error using a session ID
  static void logError({
    required int statusCode,
    required String uri,
    String? errorType,
    String? errorMessage,
    dynamic responseData,
    String? id,
  }) {
    String sessionId = id ?? "";

    // Fallback if no ID — try to find an active request for this URI
    if (sessionId.isEmpty) {
      for (var entry in _activeGroups.entries) {
        if (entry.value.uri == uri) {
          sessionId = entry.key;
          break;
        }
      }
    }

    // If still no ID, create a standalone log group
    if (sessionId.isEmpty) {
      String method = _uriMethodMap[uri] ?? 'ERROR';
      sessionId = startRequest(method: method, uri: uri);
      _uriMethodMap.remove(uri);
    }

    // Calculate response size
    int? responseSize;
    if (responseData != null) {
      if (responseData is String) {
        responseSize = responseData.length;
      } else {
        try {
          responseSize = responseData.toString().length;
        } catch (_) {}
      }
    }

    addLogEntryToGroup(
        "❌ [ERROR] StatusCode: $statusCode $uri", ZSLogType.error, sessionId);
    if (errorType != null) {
      addLogEntryToGroup("Error Type: $errorType", ZSLogType.error, sessionId);
    }
    if (errorMessage != null) {
      addLogEntryToGroup(
          "Error Message: $errorMessage", ZSLogType.error, sessionId);
    }
    if (responseData != null) {
      addLogEntryToGroup("Response: $responseData", ZSLogType.error, sessionId);
    }

    endRequest(sessionId,
        statusCode: statusCode, isError: true, responseSize: responseSize);
  }

  /// Legacy method for backward compatibility
  /// Creates a standalone log entry that auto-closes
  static void log(String message) {
    addLogEntry(message, ZSLogType.info, autoClose: true);
  }

  static List<ZSRequestLogGroup> get logGroups => List.unmodifiable(_logGroups);

  /// Refresh logs by reloading from storage
  static Future<void> refresh() async {
    final storedGroups = await ZSStorageManager.loadLogGroups();
    _logGroups.clear();
    _logGroups.addAll(storedGroups);
  }

  static void clear() {
    _logGroups.clear();
    _activeGroups.clear();
    _activeStopwatches.clear();
    _uriMethodMap.clear();
    ZSStorageManager.clearLogs();
  }

  static void deleteLogGroup(String id) {
    _logGroups.removeWhere((group) => group.id == id);
    ZSStorageManager.saveLogGroups(_logGroups);
  }

  static void deleteLogGroups(List<String> ids) {
    _logGroups.removeWhere((group) => ids.contains(group.id));
    ZSStorageManager.saveLogGroups(_logGroups);
  }
}
