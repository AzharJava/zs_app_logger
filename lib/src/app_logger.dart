import 'package:flutter/foundation.dart';

import 'models/log_entry.dart';
import 'models/request_log_group.dart';
import 'storage_manager.dart';

class ZSAppLogger {
  static final List<ZSRequestLogGroup> _logGroups = [];
  static ZSRequestLogGroup? _currentGroup;
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
    print("🔥 AppLogger initialized");
  }

  /// Start a new request log group
  static void startRequest({
    required String method,
    required String uri,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _currentGroup = ZSRequestLogGroup(
      id: id,
      method: method,
      uri: uri,
      timestamp: DateTime.now(),
      entries: [],
    );
  }

  /// Add a log entry to the current request group
  static void addLogEntry(String message, ZSLogType type,
      {bool autoClose = false}) {
    final entry = ZSLogEntry(
      message: message,
      timestamp: DateTime.now(),
      type: type,
    );

    if (_currentGroup != null) {
      _currentGroup!.entries.add(entry);

      // Update status code and error flag if it's a response or error
      if (type == ZSLogType.response) {
        final statusMatch =
            RegExp(r'statusCode[:\s]+(\d+)', caseSensitive: false)
                .firstMatch(message);
        if (statusMatch != null) {
          _currentGroup = ZSRequestLogGroup(
            id: _currentGroup!.id,
            method: _currentGroup!.method,
            uri: _currentGroup!.uri,
            timestamp: _currentGroup!.timestamp,
            entries: _currentGroup!.entries,
            statusCode: int.tryParse(statusMatch.group(1)!),
            isError: false,
          );
        }
      } else if (type == ZSLogType.error) {
        _currentGroup = ZSRequestLogGroup(
          id: _currentGroup!.id,
          method: _currentGroup!.method,
          uri: _currentGroup!.uri,
          timestamp: _currentGroup!.timestamp,
          entries: _currentGroup!.entries,
          statusCode: _currentGroup!.statusCode,
          isError: true,
        );
      }
    } else {
      // If no current group, extract meaningful info from message
      String method = 'INFO';
      String uri = 'Application Log';

      // Try to extract method and URI from message
      final methodMatch = RegExp(
              r'\b(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS)\b',
              caseSensitive: false)
          .firstMatch(message);
      if (methodMatch != null) {
        method = methodMatch.group(1)!.toUpperCase();
      }

      // Try to extract URL/endpoint
      final uriMatch = RegExp(r'(https?://[^\s]+|/[^\s]*)').firstMatch(message);
      if (uriMatch != null) {
        uri = uriMatch.group(1)!;
      } else {
        // Try to extract a meaningful identifier from the message
        // Look for common patterns like "Error:", "Warning:", "Success:", etc.
        final prefixMatch = RegExp(
                r'^(Error|Warning|Info|Success|Debug)[:\s]+(.+)',
                caseSensitive: false)
            .firstMatch(message.trim());
        if (prefixMatch != null) {
          method = prefixMatch.group(1)!.toUpperCase();
          final content = prefixMatch.group(2)!.trim();
          if (content.length > 50) {
            uri = '${content.substring(0, 50)}...';
          } else {
            uri = content;
          }
        } else {
          // Use first meaningful part of message as URI
          final trimmed = message.trim();
          // Remove common prefixes
          final cleaned = trimmed
              .replaceFirst(RegExp(r'^\[.*?\]\s*'), '')
              .replaceFirst(RegExp(r'^[➡️✅❌]\s*'), '')
              .trim();

          if (cleaned.isNotEmpty) {
            if (cleaned.length > 50) {
              uri = '${cleaned.substring(0, 50)}...';
            } else {
              uri = cleaned;
            }
          }
        }
      }

      startRequest(method: method, uri: uri);
      _currentGroup!.entries.add(entry);

      // Auto-close standalone logs
      if (autoClose) {
        endRequest();
      }
    }

    if (kDebugMode) print(entry.formattedMessage);
  }

  /// End the current request group and save it
  static void endRequest() {
    if (_currentGroup != null) {
      _logGroups.add(_currentGroup!);
      ZSStorageManager.saveLogGroups(_logGroups);
      _currentGroup = null;
    }
  }

  /// Log a request (creates a new group)
  static void logRequest({
    required String method,
    required String uri,
    Map<String, dynamic>? headers,
    dynamic body,
    String? token,
  }) {
    // Store the method for this URI in case we need it later
    _uriMethodMap[uri] = method;
    // Clean up old entries to prevent memory leak
    if (_uriMethodMap.length > _maxUriMethodEntries) {
      final keysToRemove = _uriMethodMap.keys
          .take(_uriMethodMap.length - _maxUriMethodEntries)
          .toList();
      for (final key in keysToRemove) {
        _uriMethodMap.remove(key);
      }
    }

    startRequest(method: method, uri: uri);
    addLogEntry("➡️ [REQUEST] $method $uri", ZSLogType.request);
    if (headers != null) {
      addLogEntry("Headers: $headers", ZSLogType.request);
    }
    if (body != null) {
      addLogEntry("Body: $body", ZSLogType.request);
    }
    if (token != null) {
      addLogEntry("Token: $token", ZSLogType.request);
    }
  }

  /// Log a response (adds to current group)
  static void logResponse({
    required int statusCode,
    required String uri,
    dynamic data,
  }) {
    // If no current group, create one with the method from our map
    if (_currentGroup == null) {
      // Try to get method from our URI method map
      String method = _uriMethodMap[uri] ?? 'GET';
      startRequest(method: method, uri: uri);
      // Remove from map after use
      _uriMethodMap.remove(uri);
    }

    addLogEntry(
        "✅ [RESPONSE] StatusCode: $statusCode $uri", ZSLogType.response);
    if (data != null) {
      addLogEntry("Response Data: $data", ZSLogType.response);
    }
    endRequest();
  }

  /// Log an error (adds to current group or creates new one)
  static void logError({
    required int statusCode,
    required String uri,
    String? errorType,
    String? errorMessage,
    dynamic responseData,
  }) {
    // If no current group, create one with the method from our map
    if (_currentGroup == null) {
      // Try to get method from our URI method map
      String method = _uriMethodMap[uri] ?? 'ERROR';
      startRequest(method: method, uri: uri);
      // Remove from map after use
      _uriMethodMap.remove(uri);
    }

    addLogEntry("❌ [ERROR] StatusCode: $statusCode $uri", ZSLogType.error);
    if (errorType != null) {
      addLogEntry("Error Type: $errorType", ZSLogType.error);
    }
    if (errorMessage != null) {
      addLogEntry("Error Message: $errorMessage", ZSLogType.error);
    }
    if (responseData != null) {
      addLogEntry("Response: $responseData", ZSLogType.error);
    }

    // Ensure the status code is set on the group before ending
    if (_currentGroup != null) {
      _currentGroup = ZSRequestLogGroup(
        id: _currentGroup!.id,
        method: _currentGroup!.method,
        uri: _currentGroup!.uri,
        timestamp: _currentGroup!.timestamp,
        entries: _currentGroup!.entries,
        statusCode: statusCode > 0 ? statusCode : _currentGroup!.statusCode,
        isError: true,
      );
    }

    endRequest();
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
    _currentGroup = null;
    _uriMethodMap.clear();
    ZSStorageManager.clearLogs();
  }

  static void deleteLogGroup(String id) {
    _logGroups.removeWhere((group) => group.id == id);
    ZSStorageManager.saveLogGroups(_logGroups);
  }
}
