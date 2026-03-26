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

  ZSRequestLogGroup({
    required this.id,
    required this.method,
    required this.uri,
    required this.timestamp,
    required this.entries,
    this.statusCode,
    this.isError = false,
    this.token,
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
    );
  }

  String get displayTitle => "$method $uri";
}
