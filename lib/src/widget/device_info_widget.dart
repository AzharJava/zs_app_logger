import 'dart:async';
import 'package:flutter/material.dart';

class ZSAppLoggerDeviceInfo extends StatefulWidget {
  final String appVersion;
  final String osVersion;
  final String batteryLevel;
  final String deviceId;
  final String environment;
  final double horizontalPadding;

  const ZSAppLoggerDeviceInfo({
    super.key,
    required this.appVersion,
    required this.osVersion,
    required this.batteryLevel,
    required this.deviceId,
    required this.environment,
    required this.horizontalPadding,
  });

  @override
  State<ZSAppLoggerDeviceInfo> createState() => _ZSAppLoggerDeviceInfoState();
}

class _ZSAppLoggerDeviceInfoState extends State<ZSAppLoggerDeviceInfo> {
  late ScrollController _scrollController;
  Timer? _scrollTimer;
  bool _isInteracting = false;
  double _scrollSpeed =
      0.5; // pixels per frame approx (controlled by timer frequency)

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || _isInteracting || !_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;

      if (currentScroll >= maxScroll) {
        // Reset to beginning if at the end
        _scrollController.jumpTo(0);
      } else {
        _scrollController.jumpTo(currentScroll + _scrollSpeed);
      }
    });
  }

  void _stopAutoScroll() {
    _scrollTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          widget.horizontalPadding, 12, widget.horizontalPadding, 8),
      color: const Color(0xFF1A1F23),
      child: Column(
        children: [
          Listener(
            onPointerDown: (_) {
              setState(() => _isInteracting = true);
              _stopAutoScroll();
            },
            onPointerUp: (_) {
              setState(() => _isInteracting = false);
              // Wait a bit before resuming
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted && !_isInteracting) {
                  _startAutoScroll();
                }
              });
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _infoItem(Icons.bookmark_outline_rounded, 'App Version',
                      widget.appVersion),
                  const SizedBox(width: 20),
                  _infoItem(
                      Icons.public_rounded, 'Environment', widget.environment),
                  const SizedBox(width: 20),
                  _infoItem(Icons.info_outline_rounded, 'OS Version',
                      widget.osVersion),
                  const SizedBox(width: 20),
                  _infoItem(Icons.battery_charging_full_rounded, 'Battery',
                      widget.batteryLevel),
                  const SizedBox(width: 20),
                  _infoItem(Icons.phone_android_rounded, 'Device ID',
                      widget.deviceId),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Colors.cyanAccent),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }
}
