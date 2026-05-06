import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import 'app_logger.dart';
import 'logger_config.dart';
import 'models/request_log_group.dart';
import 'service/log_export_service.dart';
import 'utils/log_ui_utils.dart';
import 'widget/device_info_widget.dart';
import 'widget/filter_panel_widget.dart';
import 'widget/log_item_widget.dart';
import 'widget/sort_sheet_widget.dart';
import 'widget/stats_row_widget.dart';

enum SortBy { latest, oldest, method, statusCode, uri }

enum FilterStatus { all, success, error, clientError, serverError }

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  String _searchQuery = '';
  final Set<String> _selectedMethods = {};
  FilterStatus _filterStatus = FilterStatus.all;
  SortBy _sortBy = SortBy.latest;
  bool _showFilters = false;
  bool _showStats = true;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isRefreshing = false;
  final Set<String> _selectedGroupIds = {};

  String _deviceId = 'Unknown';
  String _osVersion = 'Unknown';
  String _batteryLevel = 'Unknown';
  String _appVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    // Refresh logs on init (silent) to ensure latest logs are loaded after restart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshLogs(silent: true);
      _initDeviceInfo();
    });
  }

  Future<void> _initDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final battery = Battery();
    final packageInfo = await PackageInfo.fromPlatform();

    String deviceId = 'Unknown';
    String osVersion = 'Unknown';
    String batteryLevel = 'Unknown';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        osVersion =
            'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'Unknown';
        osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      }

      final level = await battery.batteryLevel;
      batteryLevel = '$level%';
    } catch (e) {
      debugPrint('Error fetching device info: $e');
    }

    if (mounted) {
      setState(() {
        _deviceId = deviceId;
        _osVersion = osVersion;
        _batteryLevel = batteryLevel;
        _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      });
    }
  }

  String get _environmentName {
    final env = ZSLoggerConfig().environment;
    switch (env) {
      case LoggerEnvironment.development:
        return 'FUTURE';
      case LoggerEnvironment.qa:
        return 'STAGING';
      case LoggerEnvironment.production:
        return 'PRODUCTION';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Debounce rapid typing to avoid excessive rebuilds
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _searchQuery = value.toLowerCase());
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedGroupIds.contains(id)) {
        _selectedGroupIds.remove(id);
      } else {
        _selectedGroupIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedGroupIds.clear();
    });
  }

  Future<void> _refreshLogs({bool silent = false}) async {
    if (mounted) {
      setState(() {
        _isRefreshing = true;
      });
    }
    try {
      await ZSAppLogger.refresh();
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Logs refreshed successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Error refreshing logs: $e'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          );
        }
      }
    }
  }

  List<ZSRequestLogGroup> get _filteredGroups {
    var groups = ZSAppLogger.logGroups.toList();

    // Search filter
    if (_searchQuery.isNotEmpty) {
      groups = groups.where((group) {
        final uri = group.uri.toLowerCase();
        final method = group.method.toLowerCase();
        final statusCode = group.statusCode?.toString() ?? '';
        final entries =
            group.entries.map((e) => e.message.toLowerCase()).join(' ');
        return uri.contains(_searchQuery) ||
            method.contains(_searchQuery) ||
            statusCode.contains(_searchQuery) ||
            entries.contains(_searchQuery);
      }).toList();
    }

    // Method filter
    if (_selectedMethods.isNotEmpty) {
      groups = groups.where((group) {
        return _selectedMethods.contains(group.method.toUpperCase());
      }).toList();
    }

    // Status filter
    if (_filterStatus != FilterStatus.all) {
      groups = groups.where((group) {
        // If statusCode is null, check if it's an error by isError flag
        if (group.statusCode == null) {
          // If filter is for errors, include groups with isError flag
          if (_filterStatus == FilterStatus.error) {
            return group.isError;
          }
          // For other filters, exclude groups without status codes
          return false;
        }

        switch (_filterStatus) {
          case FilterStatus.success:
            return group.statusCode! >= 200 && group.statusCode! < 300;
          case FilterStatus.error:
            // Include both status code errors and isError flag
            return group.statusCode! >= 400 || group.isError;
          case FilterStatus.clientError:
            return group.statusCode! >= 400 && group.statusCode! < 500;
          case FilterStatus.serverError:
            return group.statusCode! >= 500;
          default:
            return true;
        }
      }).toList();
    }

    // Date filter
    if (_selectedStartDate != null || _selectedEndDate != null) {
      groups = groups.where((group) {
        final timestamp = group.timestamp;
        if (_selectedStartDate != null &&
            timestamp.isBefore(_selectedStartDate!)) {
          return false;
        }
        if (_selectedEndDate != null) {
          // Make end date inclusive by considering end of the selected day
          final endOfDay = _selectedEndDate!
              .add(const Duration(days: 1))
              .subtract(const Duration(milliseconds: 1));
          if (timestamp.isAfter(endOfDay)) {
            return false;
          }
        }
        return true;
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case SortBy.latest:
        groups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case SortBy.oldest:
        groups.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case SortBy.method:
        groups.sort((a, b) => a.method.compareTo(b.method));
        break;
      case SortBy.statusCode:
        groups.sort((a, b) {
          final aStatus = a.statusCode ?? 0;
          final bStatus = b.statusCode ?? 0;
          return aStatus.compareTo(bStatus);
        });
        break;
      case SortBy.uri:
        groups.sort((a, b) => a.uri.compareTo(b.uri));
        break;
    }

    return groups;
  }

  Map<String, dynamic> get _statistics {
    final allGroups = ZSAppLogger.logGroups;
    final total = allGroups.length;
    final success = allGroups
        .where((g) =>
            g.statusCode != null && g.statusCode! >= 200 && g.statusCode! < 300)
        .length;
    final errors = allGroups
        .where((g) =>
            // Count HTTP errors (statusCode >= 400)
            (g.statusCode != null && g.statusCode! >= 400) ||
            // Count Flutter/platform errors (isError flag or statusCode 0 with isError)
            (g.isError) ||
            // Count errors with statusCode 0 (Flutter errors)
            (g.statusCode == 0 && g.method == 'ERROR'))
        .length;

    final methodCounts = <String, int>{};
    for (var group in allGroups) {
      methodCounts[group.method.toUpperCase()] =
          (methodCounts[group.method.toUpperCase()] ?? 0) + 1;
    }

    return {
      'total': total,
      'success': success,
      'errors': errors,
      'methodCounts': methodCounts,
    };
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_selectedStartDate ?? DateTime.now())
          : (_selectedEndDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E2326),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedStartDate = picked;
        } else {
          _selectedEndDate = picked;
        }
      });
    }
  }

  Future<void> _copyToClipboard(String text, String type) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('$type copied to clipboard'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  String _formatGroupLogs(ZSRequestLogGroup group) {
    final buffer = StringBuffer();
    buffer.writeln(
        '┌──────────────────────────────────────────────────────────────');
    buffer.writeln('│ 🚀 [${group.method}] ${group.uri}');
    buffer.writeln('│ 🕒 ${LogUIUtils.formatTimestamp(group.timestamp)}');
    buffer.writeln('│ 📊 Status: ${group.statusCode ?? 'N/A'}');
    buffer.writeln(
        '├──────────────────────────────────────────────────────────────');
    for (var entry in group.entries) {
      buffer.writeln('│ ${entry.formattedMessage}');
    }
    buffer.writeln(
        '└──────────────────────────────────────────────────────────────\n');
    return buffer.toString();
  }

  void _openSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1F23),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return ZSSortBySheet(
          currentSortBy: _sortBy,
          onSortSelected: (s) {
            setState(() => _sortBy = s);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredGroups = _filteredGroups;
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final viewPadding = media.padding;
    final isNarrow = width < 420;
    final isCompactPhone = width < 360;
    final isTablet = width >= 600;
    final horizontalPadding =
        isCompactPhone ? 10.0 : (isNarrow ? 12.0 : (isTablet ? 20.0 : 14.0));
    final stats = _statistics;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E10),
      appBar: _selectedGroupIds.isNotEmpty
          ? AppBar(
              backgroundColor: const Color(0xFF1E2326),
              elevation: 2,
              leading: IconButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.transparent),
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                ),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: _exitSelectionMode,
              ),
              title: Text(
                '${_selectedGroupIds.length} selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.all(Colors.transparent),
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                  ),
                  icon:
                      const Icon(Icons.delete_rounded, color: Colors.redAccent),
                  onPressed: _showBulkDeleteDialog,
                ),
                const SizedBox(width: 8),
              ],
            )
          : AppBar(
              backgroundColor: const Color(0xFF1A1F23),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 1,
              toolbarHeight: isCompactPhone ? 48 : kToolbarHeight,
              leading: Navigator.canPop(context)
                  ? IconButton(
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.all(Colors.transparent),
                        overlayColor:
                            WidgetStateProperty.all(Colors.transparent),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.maybePop(context),
                    )
                  : null,
              title: Text(
                'App Logs',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: isCompactPhone ? 17 : 20,
                  letterSpacing: -0.3,
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.all(Colors.transparent),
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                  ),
                  color: const Color(0xFF1A1F23),
                  surfaceTintColor: Colors.transparent,
                  position: PopupMenuPosition.under,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        )
                      : const Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white,
                        ),
                  onSelected: (value) {
                    switch (value) {
                      case 'refresh':
                        if (!_isRefreshing) _refreshLogs();
                        break;
                      case 'export':
                        if (_filteredGroups.isNotEmpty) {
                          LogExportService.exportLogs(
                            context: context,
                            groups: _filteredGroups,
                            appVersion: _appVersion,
                            osVersion: _osVersion,
                            batteryLevel: _batteryLevel,
                            deviceId: _deviceId,
                            environment: _environmentName,
                          );
                        }
                        break;
                      case 'clear':
                        _showClearAllDialog();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'refresh',
                      enabled: !_isRefreshing,
                      child: Row(
                        children: [
                          const Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          const Text('Refresh Logs',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'export',
                      enabled: _filteredGroups.isNotEmpty,
                      child: Row(
                        children: [
                          const Icon(Icons.download_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          const Text('Export Logs',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_sweep_rounded,
                              color: Colors.redAccent, size: 20),
                          const SizedBox(width: 12),
                          const Text('Clear All Logs',
                              style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  color: const Color(0xFF1A1F23),
                  surfaceTintColor: Colors.transparent,
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.all(Colors.transparent),
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                  ),
                  position: PopupMenuPosition.under,
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'stats':
                        setState(() => _showStats = !_showStats);
                        break;
                      case 'filters':
                        setState(() => _showFilters = !_showFilters);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'stats',
                      child: Row(
                        children: [
                          Icon(
                            _showStats
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            color:
                                _showStats ? Colors.cyanAccent : Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Show Stats',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'filters',
                      child: Row(
                        children: [
                          Icon(
                            _showFilters
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            color: _showFilters
                                ? Colors.cyanAccent
                                : Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Show Filters',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: Column(
        children: [
          ZSAppLoggerDeviceInfo(
            appVersion: _appVersion,
            osVersion: _osVersion,
            batteryLevel: _batteryLevel,
            deviceId: _deviceId,
            environment: _environmentName,
            horizontalPadding: horizontalPadding,
          ),
          Material(
            color: const Color(0xFF1A1F23),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ZSAppLoggerStats(
                    stats: stats,
                    isNarrow: isNarrow,
                    isCompactPhone: isCompactPhone,
                    filteredGroupsLength: filteredGroups.length,
                    showStats: _showStats,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _searchController,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompactPhone ? 15 : 14,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF121518),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Colors.white24),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF4DD0E1),
                                width: 1.5,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.white.withValues(alpha: 0.55),
                              size: 22,
                            ),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    style: ButtonStyle(
                                      backgroundColor: WidgetStateProperty.all(
                                        Colors.transparent,
                                      ),
                                      overlayColor: WidgetStateProperty.all(
                                        Colors.transparent,
                                      ),
                                    ),
                                    tooltip: 'Clear',
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      size: 20,
                                      color:
                                          Colors.white.withValues(alpha: 0.5),
                                    ),
                                    onPressed: () {
                                      _debounce?.cancel();
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  ),
                            hintText: 'Search logs…',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.38),
                              fontSize: 14,
                            ),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _openSortSheet,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 48),
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: const Color(0xFF121518),
                        ),
                        child: const Icon(
                          Icons.sort_rounded,
                          color: Colors.cyanAccent,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Filter Panel (compact)
          if (_showFilters)
            ZSAppLoggerFilterPanel(
              selectedMethods: _selectedMethods,
              filterStatus: _filterStatus,
              selectedStartDate: _selectedStartDate,
              selectedEndDate: _selectedEndDate,
              horizontalPadding: horizontalPadding,
              isNarrow: isNarrow,
              onMethodToggle: (method) {
                setState(() {
                  if (_selectedMethods.contains(method)) {
                    _selectedMethods.remove(method);
                  } else {
                    _selectedMethods.add(method);
                  }
                });
              },
              onStatusChange: (status) {
                setState(() => _filterStatus = status);
              },
              onDateSelect: (isStart) => _selectDate(context, isStart),
              onClearFilters: () {
                setState(() {
                  _selectedMethods.clear();
                  _filterStatus = FilterStatus.all;
                  _selectedStartDate = null;
                  _selectedEndDate = null;
                });
              },
              onClearDates: () {
                setState(() {
                  _selectedStartDate = null;
                  _selectedEndDate = null;
                });
              },
            ),

          // Logs List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refreshLogs(silent: false),
              color: Colors.cyanAccent,
              backgroundColor: const Color(0xFF1A1F23),
              child: filteredGroups.isEmpty
                  ? ListView(
                      // Use ListView to make it scrollable even when empty for RefreshIndicator
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _searchQuery.isNotEmpty ||
                                          _selectedMethods.isNotEmpty ||
                                          _filterStatus != FilterStatus.all
                                      ? Icons.search_off
                                      : Icons.list_alt,
                                  size: 64,
                                  color: Colors.white24,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty ||
                                          _selectedMethods.isNotEmpty ||
                                          _filterStatus != FilterStatus.all
                                      ? 'No logs match your filters'
                                      : 'No logs yet...',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        8,
                        horizontalPadding,
                        12 + viewPadding.bottom,
                      ),
                      itemCount: filteredGroups.length,
                      itemBuilder: (context, index) {
                        final group = filteredGroups[index];
                        return ZSLogItemWidget(
                          key: ValueKey(group.id),
                          group: group,
                          isNarrow: isNarrow,
                          isCompactPhone: isCompactPhone,
                          isSelectionMode: _selectedGroupIds.isNotEmpty,
                          isSelected: _selectedGroupIds.contains(group.id),
                          onSelected: () => _toggleSelection(group.id),
                          onLongPress: () => _toggleSelection(group.id),
                          onDelete: _showDeleteDialog,
                          onCopy: _copyToClipboard,
                          onShare: _shareText,
                          formatGroupLogs: _formatGroupLogs,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(ZSRequestLogGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2326),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            const Text(
              'Delete Log?',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this log entry?\n\n${group.method} ${group.uri}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ZSAppLogger.deleteLogGroup(group.id);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Log deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _showBulkDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2326),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            const Text(
              'Delete Logs?',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedGroupIds.length} selected log entries?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final idsToDelete = _selectedGroupIds.toList();
      ZSAppLogger.deleteLogGroups(idsToDelete);
      _exitSelectionMode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${idsToDelete.length} logs deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showClearAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2326),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            const Text(
              'Clear All Logs?',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear all logs? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ZSAppLogger.clear();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All logs cleared successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _shareText(String text, String subject) async {
    try {
      await Share.share(text, subject: subject);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
