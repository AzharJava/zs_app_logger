import 'log_entry.dart';

class ZSRequestLogGroup {
  final String id;
  final String method;
  final String uri;
  final DateTime timestamp;
  final List<ZSLogEntry> entries;
  final int? statusCode;
  final bool isError;
  final String? token;
  final int? duration; // In milliseconds
  final int? responseSize; // In bytes

  ZSRequestLogGroup({
    required this.id,
    required this.method,
    required this.uri,
    required this.timestamp,
    required this.entries,
    this.statusCode,
    this.isError = false,
    this.token,
    this.duration,
    this.responseSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'method': method,
      'uri': uri,
      'timestamp': timestamp.toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
      'statusCode': statusCode,
      'isError': isError,
      'token': token,
      'duration': duration,
      'responseSize': responseSize,
    };
  }

  factory ZSRequestLogGroup.fromJson(Map<String, dynamic> json) {
    return ZSRequestLogGroup(
      id: json['id'] as String,
      method: json['method'] as String,
      uri: json['uri'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      entries: (json['entries'] as List<dynamic>)
          .map((e) => ZSLogEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      statusCode: json['statusCode'] as int?,
      isError: json['isError'] as bool? ?? false,
      token: json['token'] as String?,
      duration: json['duration'] as int?,
      responseSize: json['responseSize'] as int?,
    );
  }

  String get displayTitle => "$method $uri";
}
