import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'app_logger.dart';
import 'models/log_entry.dart';
import 'models/request_log_group.dart';
import 'utils/app_logger_path.dart';
import 'widget/compact_state_item_widget.dart';
import 'widget/small_chips_widget.dart';

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

  @override
  void initState() {
    super.initState();
    // Use debounced onChanged from the text field instead of controller listener
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

  Future<void> _refreshLogs() async {
    setState(() {
      _isRefreshing = true;
    });
    try {
      await ZSAppLogger.refresh();
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
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

  Color _getLogColor(ZSLogEntry entry) {
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

  Color _getMethodColor(String method) {
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

  IconData _getMethodIcon(String method) {
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

  IconData _getLogTypeIcon(ZSLogType type) {
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

  Color _getGroupColor(ZSRequestLogGroup group) {
    if (group.isError) {
      return Colors.redAccent.shade200;
    }
    final methodColor = _getMethodColor(group.method);
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

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
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

  void _exportLogs() {
    final logs = _filteredGroups.map((group) {
      final buffer = StringBuffer();
      buffer.writeln(
          '┌──────────────────────────────────────────────────────────────');
      buffer.writeln('│ 🚀 [${group.method}] ${group.uri}');
      buffer.writeln('│ 🕒 ${_formatTimestamp(group.timestamp)}');
      buffer.writeln('│ 📊 Status: ${group.statusCode ?? 'N/A'}');
      buffer.writeln(
          '├──────────────────────────────────────────────────────────────');
      for (var entry in group.entries) {
        buffer.writeln('│ ${entry.formattedMessage}');
      }
      buffer.writeln(
          '└──────────────────────────────────────────────────────────────\n');
      return buffer.toString();
    }).join('\n');

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
              logs,
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
              //check the empty if logs empty then not download
              if (logs.isNotEmpty) {
                await _downloadLogs(logs);
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

  Future<void> _downloadLogs(String logs) async {
    try {
      // Generate filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'app_logs_$timestamp.txt';

      // Save the file to Downloads folder
      final file = await writeBytesToDownloadsZSAppLogger(logs, filename);

      if (file != null && context.mounted) {
        // For web, file is a String (filename), for other platforms it's a File object
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
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isWeb ? 'File downloaded: $filePath' : filePath,
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: isWeb
                ? null
                : SnackBarAction(
                    label: 'Open',
                    textColor: Colors.white,
                    onPressed: () async {
                      await openFileInNativeViewZSAppLogger(filePath);
                    },
                  ),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Text('Failed to save logs'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Error saving logs: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
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
    buffer.writeln('│ 🕒 ${_formatTimestamp(group.timestamp)}');
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

  static String _sortLabel(SortBy s) {
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

  void _openSortSheet() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1F23),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset + 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Sort logs',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ...SortBy.values.map(
                (s) => ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: Icon(
                    Icons.sort_rounded,
                    color: _sortBy == s ? Colors.cyanAccent : Colors.white38,
                  ),
                  title: Text(
                    _sortLabel(s),
                    style: TextStyle(
                      color: _sortBy == s ? Colors.cyanAccent : Colors.white70,
                      fontWeight:
                          _sortBy == s ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  trailing: _sortBy == s
                      ? const Icon(Icons.check_rounded,
                          color: Colors.cyanAccent)
                      : null,
                  onTap: () {
                    setState(() => _sortBy = s);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMethodChipsRow(Map<String, int> methodCounts) {
    if (methodCounts.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: methodCounts.entries.take(6).map((entry) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ZSAppLoggerSmallChipsWidget(
              colors: [
                _getMethodColor(entry.key).withValues(alpha: 0.18),
                _getMethodColor(entry.key).withValues(alpha: 0.08),
              ],
              methodColor: _getMethodColor(entry.key),
              methodIcon: _getMethodIcon(entry.key),
              method: entry.key,
              value: entry.value.toString(),
            ),
          );
        }).toList(),
      ),
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
    final availableMethods = [
      'GET',
      'POST',
      'PUT',
      'DELETE',
      'PATCH',
      'HEAD',
      'OPTIONS'
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F23),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        toolbarHeight: isCompactPhone ? 48 : kToolbarHeight,
        leading: Navigator.canPop(context)
            ? IconButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.transparent),
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                ),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
          IconButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.transparent),
              overlayColor: WidgetStateProperty.all(Colors.transparent),
            ),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                  ),
            onPressed: _isRefreshing ? null : _refreshLogs,
          ),
          IconButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.transparent),
              overlayColor: WidgetStateProperty.all(Colors.transparent),
            ),
            tooltip: 'Export Logs',
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: () {
              if (_filteredGroups.isNotEmpty) _exportLogs();
            },
          ),
          IconButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.transparent),
              overlayColor: WidgetStateProperty.all(Colors.transparent),
            ),
            tooltip: 'Clear Logs',
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
            onPressed: () {
              ZSAppLogger.clear();
              setState(() {});
            },
          ),
          PopupMenuButton<String>(
            color: Colors.black,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.transparent),
              overlayColor: WidgetStateProperty.all(Colors.transparent),
            ),
            position: PopupMenuPosition.under,
            icon: Icon(
              Icons.more_vert,
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
                      color: _showStats ? Colors.cyanAccent : Colors.white54,
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
                      color: _showFilters ? Colors.cyanAccent : Colors.white54,
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
          // Stats + search (responsive; avoids horizontal overflow on phones)
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
                  if (_showStats) ...[
                    if (isNarrow)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ZSCompactStatItem(
                              label: 'Total',
                              value: '${stats['total']}',
                              color: Colors.blueAccent,
                              compact: true,
                              stretch: true,
                            ),
                          ),
                          SizedBox(width: isCompactPhone ? 6 : 8),
                          Expanded(
                            child: ZSCompactStatItem(
                              label: 'OK',
                              value: '${stats['success']}',
                              color: Colors.greenAccent,
                              compact: true,
                              stretch: true,
                            ),
                          ),
                          SizedBox(width: isCompactPhone ? 6 : 8),
                          Expanded(
                            child: ZSCompactStatItem(
                              label: 'Err',
                              value: '${stats['errors']}',
                              color: Colors.redAccent,
                              compact: true,
                              stretch: true,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ZSCompactStatItem(
                            label: 'Total',
                            value: '${stats['total']}',
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 8),
                          ZSCompactStatItem(
                            label: 'Success',
                            value: '${stats['success']}',
                            color: Colors.greenAccent,
                          ),
                          const SizedBox(width: 8),
                          ZSCompactStatItem(
                            label: 'Errors',
                            value: '${stats['errors']}',
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 10),
                        ],
                      ),
                    SizedBox(height: isNarrow ? 10 : 8),
                    if (isNarrow)
                      Text(
                        '${filteredGroups.length} shown',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (isNarrow) const SizedBox(height: 6),
                    _buildMethodChipsRow(
                      stats['methodCounts'] as Map<String, int>,
                    ),
                    SizedBox(height: isNarrow ? 12 : 10),
                  ],
                  if (isNarrow)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
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
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _openSortSheet,
                          icon: const Icon(Icons.sort_rounded, size: 18),
                          label: Text(
                            'Sort: ${_sortLabel(_sortBy)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.cyanAccent.shade100,
                            side: BorderSide(
                              color: Colors.cyanAccent.withValues(alpha: 0.35),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _searchController,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTablet ? 14 : 13,
                            ),
                            decoration: InputDecoration(
                              isDense: !isTablet,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: isTablet ? 14 : 10,
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
                                size: 20,
                              ),
                              suffixIcon: _searchQuery.isEmpty
                                  ? null
                                  : IconButton(
                                      style: ButtonStyle(
                                        backgroundColor:
                                            WidgetStateProperty.all(
                                          Colors.transparent,
                                        ),
                                        overlayColor: WidgetStateProperty.all(
                                          Colors.transparent,
                                        ),
                                      ),
                                      tooltip: 'Clear search',
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
                              hintText: 'Method, URI, status, message…',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.38),
                                fontSize: 13,
                              ),
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF15191C),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<SortBy>(
                              value: _sortBy,
                              dropdownColor: const Color(0xFF1E2326),
                              borderRadius: BorderRadius.circular(12),
                              icon: Icon(
                                Icons.arrow_drop_down_rounded,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              style: TextStyle(
                                color: Colors.amber.shade100,
                                fontSize: isTablet ? 13 : 12,
                              ),
                              items: SortBy.values
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(_sortLabel(s)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _sortBy = value);
                                }
                              },
                            ),
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
            Container(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                10,
              ),
              color: const Color(0xFF15191C),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedMethods.isNotEmpty ||
                          _filterStatus != FilterStatus.all ||
                          _selectedStartDate != null ||
                          _selectedEndDate != null)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedMethods.clear();
                                _filterStatus = FilterStatus.all;
                                _selectedStartDate = null;
                                _selectedEndDate = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.clear,
                                      size: 14, color: Colors.redAccent),
                                  SizedBox(width: 4),
                                  Text(
                                    'Clear',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Method Filter (compact)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: availableMethods.map((method) {
                      final isSelected = _selectedMethods.contains(method);
                      final methodColor = _getMethodColor(method);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedMethods.remove(method);
                              } else {
                                _selectedMethods.add(method);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? methodColor.withValues(alpha: 0.25)
                                  : const Color(0xFF1E2326)
                                      .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? methodColor.withValues(alpha: 0.6)
                                    : Colors.white24,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getMethodIcon(method),
                                  size: 14,
                                  color:
                                      isSelected ? methodColor : Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  method,
                                  style: TextStyle(
                                    color: isSelected
                                        ? methodColor
                                        : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: methodColor,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  // Status Filter (scroll on narrow phones)
                  if (isNarrow)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusChip('All', FilterStatus.all),
                          const SizedBox(width: 6),
                          _buildStatusChip('OK', FilterStatus.success),
                          const SizedBox(width: 6),
                          _buildStatusChip('Err', FilterStatus.error),
                          const SizedBox(width: 6),
                          _buildStatusChip('4xx', FilterStatus.clientError),
                          const SizedBox(width: 6),
                          _buildStatusChip('5xx', FilterStatus.serverError),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildStatusChip('All', FilterStatus.all),
                        _buildStatusChip('Success', FilterStatus.success),
                        _buildStatusChip('Errors', FilterStatus.error),
                        _buildStatusChip('4xx', FilterStatus.clientError),
                        _buildStatusChip('5xx', FilterStatus.serverError),
                      ],
                    ),
                  const SizedBox(height: 8),
                  // Date Filter (compact)
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2326),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 14, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedStartDate == null
                                        ? 'Start'
                                        : _formatDate(_selectedStartDate!),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2326),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 14, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedEndDate == null
                                        ? 'End'
                                        : _formatDate(_selectedEndDate!),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_selectedStartDate != null ||
                          _selectedEndDate != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: IconButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(
                                Colors.transparent,
                              ),
                              overlayColor: WidgetStateProperty.all(
                                Colors.transparent,
                              ),
                            ),
                            icon: const Icon(Icons.clear,
                                color: Colors.white70, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _selectedStartDate = null;
                                _selectedEndDate = null;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          // Logs List
          Expanded(
            child: filteredGroups.isEmpty
                ? Center(
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
                  )
                : ListView.builder(
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
                      final groupColor = _getGroupColor(group);
                      final cardRadius = BorderRadius.circular(
                        isCompactPhone ? 12 : 14,
                      );

                      return GestureDetector(
                        onLongPressStart: (details) {
                          _showDeleteDialog(group);
                        },
                        child: Container(
                          margin: EdgeInsets.only(
                            bottom: isCompactPhone ? 10 : 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF15191C),
                            borderRadius: cardRadius,
                            border: Border.all(
                              color: groupColor.withValues(alpha: 0.28),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              hoverColor: Colors.white.withValues(alpha: 0.05),
                              splashColor: groupColor.withValues(alpha: 0.12),
                            ),
                            child: ExpansionTile(
                              backgroundColor: const Color(0xFF1C1F22),
                              collapsedBackgroundColor: Colors.transparent,
                              tilePadding: EdgeInsets.symmetric(
                                horizontal: isCompactPhone ? 10 : 14,
                                vertical: isCompactPhone ? 8 : 6,
                              ),
                              childrenPadding: EdgeInsets.fromLTRB(
                                isCompactPhone ? 10 : 12,
                                4,
                                isCompactPhone ? 10 : 12,
                                10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: cardRadius,
                              ),
                              collapsedShape: RoundedRectangleBorder(
                                borderRadius: cardRadius,
                              ),
                              leading: isNarrow
                                  ? null
                                  : Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color:
                                            groupColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _getMethodIcon(group.method),
                                        color: groupColor,
                                        size: 20,
                                      ),
                                    ),

                              title: isNarrow
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    groupColor.withValues(
                                                        alpha: 0.28),
                                                    groupColor.withValues(
                                                        alpha: 0.06),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: groupColor.withValues(
                                                      alpha: 0.35),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _getMethodIcon(
                                                        group.method),
                                                    size: 14,
                                                    color: groupColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    group.method.toUpperCase(),
                                                    style: TextStyle(
                                                      color: groupColor,
                                                      fontFamily:
                                                          'JetBrainsMono',
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),
                                            if (group.statusCode != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: groupColor.withValues(
                                                      alpha: 0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: groupColor
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  '${group.statusCode}',
                                                  style: TextStyle(
                                                    color: groupColor,
                                                    fontFamily: 'JetBrainsMono',
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          group.uri,
                                          style: TextStyle(
                                            color: groupColor.withValues(
                                                alpha: 0.95),
                                            fontFamily: 'JetBrainsMono',
                                            fontSize:
                                                isCompactPhone ? 11.5 : 12,
                                            fontWeight: FontWeight.w500,
                                            height: 1.35,
                                          ),
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Container(
                                          margin:
                                              const EdgeInsets.only(right: 10),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                groupColor.withValues(
                                                    alpha: 0.25),
                                                groupColor.withValues(
                                                    alpha: 0.05),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: groupColor.withValues(
                                                  alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            group.method.toUpperCase(),
                                            style: TextStyle(
                                              color: groupColor,
                                              fontFamily: 'JetBrainsMono',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            group.uri,
                                            style: TextStyle(
                                              color: groupColor,
                                              fontFamily: 'JetBrainsMono',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (group.statusCode != null)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(left: 10),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: groupColor.withValues(
                                                  alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: groupColor.withValues(
                                                    alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              '${group.statusCode}',
                                              style: TextStyle(
                                                color: groupColor,
                                                fontFamily: 'JetBrainsMono',
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),

                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  _formatTimestamp(group.timestamp),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: isCompactPhone ? 10 : 11,
                                  ),
                                ),
                              ),

                              // 💬 Log Messages Section
                              children: [
                                // Quick actions
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Tooltip(
                                        message:
                                            'Copy all entries in this group',
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _copyToClipboard(
                                              _formatGroupLogs(group),
                                              'Log group',
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: groupColor.withValues(
                                                    alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color:
                                                        groupColor.withValues(
                                                            alpha: 0.28)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.copy,
                                                      size: 14,
                                                      color: groupColor),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Copy All',
                                                    style: TextStyle(
                                                      color: groupColor,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontFamily:
                                                          'JetBrainsMono',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: 'Share this log group',
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _shareText(
                                              _formatGroupLogs(group),
                                              'Log Group: ${group.method} ${group.uri}',
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: groupColor.withValues(
                                                    alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color:
                                                        groupColor.withValues(
                                                            alpha: 0.28)),
                                              ),
                                              child: Icon(Icons.share_rounded,
                                                  size: 14, color: groupColor),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Individual log entries
                                ...group.entries.map((entry) {
                                  final color = _getLogColor(entry);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.15),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Log Type Icon
                                        Container(
                                          margin: const EdgeInsets.only(
                                              top: 2, right: 12),
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _getLogTypeIcon(entry.type),
                                            size: 14,
                                            color: color,
                                          ),
                                        ),
                                        // Log Message
                                        Expanded(
                                          child: SelectableText(
                                            entry.message,
                                            style: TextStyle(
                                              color: color,
                                              fontFamily: 'JetBrainsMono',
                                              fontSize: 12,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                        // Copy Button
                                        const SizedBox(width: 8),
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _copyToClipboard(
                                              entry.message,
                                              'Log entry',
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Container(
                                              padding: EdgeInsets.all(
                                                isCompactPhone ? 10 : 6,
                                              ),
                                              constraints: const BoxConstraints(
                                                minWidth: 40,
                                                minHeight: 40,
                                              ),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: color.withValues(
                                                    alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.copy_rounded,
                                                size: isCompactPhone ? 18 : 16,
                                                color: color,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Share Button
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _shareText(
                                              entry.message,
                                              'Log Entry: ${group.method}',
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Container(
                                              padding: EdgeInsets.all(
                                                isCompactPhone ? 10 : 6,
                                              ),
                                              constraints: const BoxConstraints(
                                                minWidth: 40,
                                                minHeight: 40,
                                              ),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: color.withValues(
                                                    alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.share_rounded,
                                                size: isCompactPhone ? 18 : 16,
                                                color: color,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
            backgroundColor: Colors.redAccent,
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

  Widget _buildStatusChip(String label, FilterStatus status) {
    final isSelected = _filterStatus == status;
    Color chipColor;
    switch (status) {
      case FilterStatus.all:
        chipColor = Colors.grey.shade400;
        break;
      case FilterStatus.success:
        chipColor = Colors.greenAccent;
        break;
      case FilterStatus.error:
        chipColor = Colors.redAccent;
        break;
      case FilterStatus.clientError:
        chipColor = Colors.orangeAccent;
        break;
      case FilterStatus.serverError:
        chipColor = Colors.redAccent.shade400;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _filterStatus = status);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? chipColor.withValues(alpha: 0.25)
                : const Color(0xFF1E2326).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? chipColor.withValues(alpha: 0.6)
                  : Colors.white24,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? chipColor : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: chipColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
