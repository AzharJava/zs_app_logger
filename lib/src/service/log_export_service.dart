import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/request_log_group.dart';
import '../utils/log_ui_utils.dart';
import '../utils/app_logger_path.dart' as logger_path;

class LogExportService {
  static void exportLogs({
    required BuildContext context,
    required List<ZSRequestLogGroup> groups,
    required String appVersion,
    required String osVersion,
    required String batteryLevel,
    required String deviceId,
    required String environment,
  }) {
    final headerBuffer = StringBuffer();
    headerBuffer.writeln(
        '================================================================');
    headerBuffer.writeln('📱 DEVICE & APP DETAILS');
    headerBuffer.writeln(
        '================================================================');
    headerBuffer.writeln('App Version : $appVersion');
    headerBuffer.writeln('Environment : $environment');
    headerBuffer.writeln('OS Version  : $osVersion');
    headerBuffer.writeln('Battery     : $batteryLevel');
    headerBuffer.writeln('Device ID   : $deviceId');
    headerBuffer
        .writeln('Export Time : ${LogUIUtils.formatTimestamp(DateTime.now())}');
    headerBuffer.writeln(
        '================================================================\n\n');


    final logs = groups.map((ZSRequestLogGroup group) {
      final buffer = StringBuffer();
      buffer.writeln(
          '================================================================');
      buffer.writeln('🚀 [${group.method}] ${group.uri}');
      buffer.writeln('🕒 ${LogUIUtils.formatTimestamp(group.timestamp)}');
      buffer.writeln(
          '📊 Status: ${group.statusCode ?? 'N/A'} | ⏱️ ${group.duration ?? 0}ms | 📦 ${LogUIUtils.formatSize(group.responseSize)}');
      buffer.writeln(
          '================================================================\n');

      for (var entry in group.entries) {
        final message = entry.message;
        if (message.startsWith('➡️ [REQUEST]')) continue;
        if (message.startsWith('✅ [RESPONSE]')) continue;
        if (message.startsWith('❌ [ERROR]')) continue;

        if (message.startsWith('Headers:')) {
          buffer.writeln('📥 [REQUEST HEADERS]');
          buffer.writeln(
              '----------------------------------------------------------------');
          buffer.writeln(LogUIUtils.prettyJson(message.substring(8).trim()));
          buffer.writeln('');
        } else if (message.startsWith('Body:')) {
          buffer.writeln('📤 [REQUEST BODY]');
          buffer.writeln(
              '----------------------------------------------------------------');
          buffer.writeln(LogUIUtils.prettyJson(message.substring(5).trim()));
          buffer.writeln('');
        } else if (message.startsWith('Token:')) {
          buffer.writeln('🔑 [AUTH TOKEN]');
          buffer.writeln(
              '----------------------------------------------------------------');
          buffer.writeln(message.substring(6).trim());
          buffer.writeln('');
        } else if (message.startsWith('Response Data:')) {
          buffer.writeln('📥 [RESPONSE BODY]');
          buffer.writeln(
              '----------------------------------------------------------------');
          buffer.writeln(LogUIUtils.prettyJson(message.substring(14).trim()));
          buffer.writeln('');
        } else if (message.startsWith('Response:')) {
          buffer.writeln('📥 [ERROR RESPONSE]');
          buffer.writeln(
              '----------------------------------------------------------------');
          buffer.writeln(LogUIUtils.prettyJson(message.substring(9).trim()));
          buffer.writeln('');
        } else if (message.startsWith('Error Type:')) {
          buffer.writeln('⚠️ [ERROR TYPE]: ${message.substring(11).trim()}');
        } else if (message.startsWith('Error Message:')) {
          buffer.writeln('📝 [ERROR MSG]: ${message.substring(14).trim()}');
        } else {
          buffer.writeln('📝 [LOG]: $message');
        }
      }
      buffer.writeln('\n');
      return buffer.toString();
    }).join('\n');

    final fullLogs = headerBuffer.toString() + logs;

    // Show dialog with logs and download option
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2326),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.description, color: Colors.lightGreenAccent),
            const SizedBox(width: 8),
            const Text(
              'Exported Logs',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: const Color(0xFF15191C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              fullLogs,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Close'),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (fullLogs.isNotEmpty) {
                await _downloadLogs(context, fullLogs);
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightGreenAccent,
              foregroundColor: const Color(0xFF0E1111),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadLogs(BuildContext context, String logs) async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'app_logs_$timestamp.txt';

      final file =
          await logger_path.writeBytesToDownloadsZSAppLogger(logs, filename);

      if (file != null && context.mounted) {
        final filePath = file is String ? file : (file as dynamic).path;
        final isWeb = file is String;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Logs saved successfully!',
                         style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        isWeb ? 'File downloaded: $filePath' : filePath,
                         style: const TextStyle(fontSize: 11, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: isWeb
                ? null
                : SnackBarAction(
                    label: 'OPEN',
                    textColor: Colors.lightGreenAccent,
                    onPressed: () {
                      logger_path.openFileInNativeViewZSAppLogger(filePath);
                    },
                  ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
