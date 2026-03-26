import 'package:intl/intl.dart';

class ZSLogEntry {
  final String message;
  final DateTime timestamp;
  final ZSLogType type;

  ZSLogEntry({
    required this.message,
    required this.timestamp,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString().split('.').last,
    };
  }

  factory ZSLogEntry.fromJson(Map<String, dynamic> json) {
    return ZSLogEntry(
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: ZSLogType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => ZSLogType.info,
      ),
    );
  }

  String get formattedMessage {
    final timeString = DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);
    return "[$timeString] $message";
  }
}

enum ZSLogType {
  request,
  response,
  error,
  info,
}
