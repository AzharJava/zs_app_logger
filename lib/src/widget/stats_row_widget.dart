import 'package:flutter/material.dart';

import '../utils/log_ui_utils.dart';
import 'compact_state_item_widget.dart';
import 'small_chips_widget.dart';

class ZSAppLoggerStats extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool isNarrow;
  final bool isCompactPhone;
  final int filteredGroupsLength;
  final bool showStats;

  const ZSAppLoggerStats({
    super.key,
    required this.stats,
    required this.isNarrow,
    required this.isCompactPhone,
    required this.filteredGroupsLength,
    required this.showStats,
  });

  @override
  Widget build(BuildContext context) {
    if (!showStats) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            '$filteredGroupsLength shown',
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
    );
  }

  Widget _buildMethodChipsRow(Map<String, int> methodCounts) {
    if (methodCounts.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: methodCounts.entries.take(6).map((entry) {
          final methodColor = LogUIUtils.getMethodColor(entry.key);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ZSAppLoggerSmallChipsWidget(
              colors: [
                methodColor.withValues(alpha: 0.18),
                methodColor.withValues(alpha: 0.08),
              ],
              methodColor: methodColor,
              methodIcon: LogUIUtils.getMethodIcon(entry.key),
              method: entry.key,
              value: entry.value.toString(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
