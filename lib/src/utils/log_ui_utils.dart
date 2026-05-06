import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../models/request_log_group.dart';
import '../log_screen.dart';

class LogUIUtils {
  static Color getLogColor(ZSLogEntry entry) {
    switch (entry.type) {
      case ZSLogType.error:
        return Colors.redAccent.shade200;
      case ZSLogType.response:
        return Colors.greenAccent.shade400;
      case ZSLogType.request:
        return Colors.amberAccent.shade200;
      case ZSLogType.info:
        return Colors.white70;
    }
  }

  static Color getMethodColor(String method) {
    final upperMethod = method.toUpperCase();
    switch (upperMethod) {
      case 'GET':
        return Colors.greenAccent.shade400;
      case 'POST':
        return Colors.blueAccent.shade400;
      case 'PUT':
        return Colors.orangeAccent.shade400;
      case 'DELETE':
        return Colors.redAccent.shade400;
      case 'PATCH':
        return Colors.purpleAccent.shade400;
      case 'HEAD':
        return Colors.cyanAccent.shade400;
      case 'OPTIONS':
        return Colors.tealAccent.shade400;
      case 'ERROR':
        return Colors.redAccent.shade200;
      case 'INFO':
        return Colors.amberAccent.shade200;
      default:
        return Colors.white70;
    }
  }

  static IconData getMethodIcon(String method) {
    final upperMethod = method.toUpperCase();
    switch (upperMethod) {
      case 'GET':
        return Icons.download_rounded;
      case 'POST':
        return Icons.upload_rounded;
      case 'PUT':
        return Icons.edit_rounded;
      case 'DELETE':
        return Icons.delete_rounded;
      case 'PATCH':
        return Icons.build_rounded;
      case 'HEAD':
        return Icons.info_outline_rounded;
      case 'OPTIONS':
        return Icons.settings_rounded;
      case 'ERROR':
        return Icons.error_outline_rounded;
      case 'INFO':
        return Icons.info_outline_rounded;
      default:
        return Icons.http_rounded;
    }
  }

  static IconData getLogTypeIcon(ZSLogType type) {
    switch (type) {
      case ZSLogType.error:
        return Icons.error_outline;
      case ZSLogType.response:
        return Icons.check_circle_outline;
      case ZSLogType.request:
        return Icons.send_outlined;
      case ZSLogType.info:
        return Icons.info_outline;
    }
  }

  static Color getGroupColor(ZSRequestLogGroup group) {
    if (group.isError) {
      return Colors.redAccent.shade200;
    }
    final methodColor = getMethodColor(group.method);
    if (group.statusCode != null && group.statusCode! >= 400) {
      return Colors.redAccent.shade200;
    }
    if (group.statusCode != null &&
        group.statusCode! >= 200 &&
        group.statusCode! < 300) {
      return methodColor;
    }
    return methodColor;
  }

  static String formatTimestamp(DateTime timestamp) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatSize(int? bytes) {
    if (bytes == null) return '0 KB';
    if (bytes < 1024) return '$bytes B';
    return '${(bytes / 1024).toStringAsFixed(2)} KB';
  }

  static String sortLabel(SortBy s) {
    switch (s) {
      case SortBy.latest:
        return 'Latest';
      case SortBy.oldest:
        return 'Oldest';
      case SortBy.method:
        return 'Method';
      case SortBy.statusCode:
        return 'Status';
      case SortBy.uri:
        return 'URI';
    }
  }

  static Color getDurationColor(int? duration) {
    if (duration == null) return Colors.amberAccent.withValues(alpha: 0.7);
    if (duration > 2500) return Colors.redAccent.withValues(alpha: 0.8);
    if (duration > 1500) return Colors.orangeAccent.withValues(alpha: 0.8);
    if (duration > 1000) return Colors.yellowAccent.withValues(alpha: 0.8);
    return Colors.greenAccent.withValues(alpha: 0.8);
  }

  static Color getSizeColor(int? sizeInBytes) {
    if (sizeInBytes == null) return Colors.amberAccent.withValues(alpha: 0.7);
    if (sizeInBytes > 1024 * 1024)
      return Colors.redAccent.withValues(alpha: 0.8);
    if (sizeInBytes > 512 * 1024)
      return Colors.orangeAccent.withValues(alpha: 0.8);
    if (sizeInBytes > 100 * 1024)
      return Colors.yellowAccent.withValues(alpha: 0.8);
    return Colors.greenAccent.withValues(alpha: 0.8);
  }

  static String prettyJson(dynamic json) {
    if (json == null) return "null";
    try {
      final object = json is String ? jsonDecode(json) : json;
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(object);
    } catch (_) {
      return json.toString();
    }
  }
}
