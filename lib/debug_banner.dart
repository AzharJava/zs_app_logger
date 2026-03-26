import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_logger.dart';

/// A small, tappable debug banner that appears only in debug mode.
/// Works with both MaterialApp and MaterialApp.router.
/// You can tap it to open your LogScreen or any custom debug page.
/// Visibility is controlled by LoggerConfig and optionally by device identifiers.
class DebugBanner extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final Color color;

  const DebugBanner({
    super.key,
    this.onTap,
    this.label = '🐞 DEBUG MODE — TAP TO VIEW LOGS',
    this.color = Colors.redAccent,
  });

  Future<String?> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor;
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Check initial configuration
    final config = ZSLoggerConfig();
    if (!config.showBugButton) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<String?>(
      future: _getDeviceId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final deviceId = snapshot.data;
        final allowedIds = config.allowedDeviceIds;

        // If specific IDs are provided, restrict visibility to those IDs
        if (allowedIds != null && allowedIds.isNotEmpty) {
          if (deviceId == null || !allowedIds.contains(deviceId)) {
            return const SizedBox.shrink();
          }
        } else {
          // If no specific IDs provided, only show in debug mode or non-prod
          if (!kDebugMode && config.isProduction) {
            return const SizedBox.shrink();
          }
        }

        return InkWell(
          onTap: onTap ??
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LogScreen()),
                );
              },
          child: Container(
            height: 24,
            alignment: Alignment.center,
            color: color.withValues(alpha: 0.9),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
        );
      },
    );
  }
}
