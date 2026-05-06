import 'package:flutter/material.dart';
import '../log_screen.dart';
import '../utils/log_ui_utils.dart';

class ZSAppLoggerFilterPanel extends StatelessWidget {
  final Set<String> selectedMethods;
  final FilterStatus filterStatus;
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final double horizontalPadding;
  final bool isNarrow;
  final Function(String) onMethodToggle;
  final Function(FilterStatus) onStatusChange;
  final Function(bool isStart) onDateSelect;
  final VoidCallback onClearFilters;
  final VoidCallback onClearDates;

  const ZSAppLoggerFilterPanel({
    super.key,
    required this.selectedMethods,
    required this.filterStatus,
    required this.selectedStartDate,
    required this.selectedEndDate,
    required this.horizontalPadding,
    required this.isNarrow,
    required this.onMethodToggle,
    required this.onStatusChange,
    required this.onDateSelect,
    required this.onClearFilters,
    required this.onClearDates,
  });

  @override
  Widget build(BuildContext context) {
    final availableMethods = [
      'GET',
      'POST',
      'PUT',
      'DELETE',
      'PATCH',
      'HEAD',
      'OPTIONS'
    ];

    return Container(
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
              if (selectedMethods.isNotEmpty ||
                  filterStatus != FilterStatus.all ||
                  selectedStartDate != null ||
                  selectedEndDate != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onClearFilters,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.clear, size: 14, color: Colors.redAccent),
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
          // Method Filter
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: availableMethods.map((method) {
              final isSelected = selectedMethods.contains(method);
              final methodColor = LogUIUtils.getMethodColor(method);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onMethodToggle(method),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? methodColor.withValues(alpha: 0.25)
                          : const Color(0xFF1E2326).withValues(alpha: 0.5),
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
                          LogUIUtils.getMethodIcon(method),
                          size: 14,
                          color: isSelected ? methodColor : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          method,
                          style: TextStyle(
                            color: isSelected ? methodColor : Colors.white70,
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
          // Status Filter
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
          // Date Filter
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onDateSelect(true),
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
                            selectedStartDate == null
                                ? 'Start'
                                : LogUIUtils.formatDate(selectedStartDate!),
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
                    onTap: () => onDateSelect(false),
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
                            selectedEndDate == null
                                ? 'End'
                                : LogUIUtils.formatDate(selectedEndDate!),
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
              if (selectedStartDate != null || selectedEndDate != null)
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
                    onPressed: onClearDates,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, FilterStatus status) {
    final isSelected = filterStatus == status;
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
        onTap: () => onStatusChange(status),
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
