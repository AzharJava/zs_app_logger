import 'package:flutter/material.dart';

import '../log_details_screen.dart';
import '../models/request_log_group.dart';
import '../utils/log_ui_utils.dart';

class ZSLogItemWidget extends StatefulWidget {
  final ZSRequestLogGroup group;
  final bool isNarrow;
  final bool isCompactPhone;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelected;
  final VoidCallback? onLongPress;
  final Function(ZSRequestLogGroup) onDelete;
  final Function(String, String) onCopy;
  final Function(String, String) onShare;
  final String Function(ZSRequestLogGroup) formatGroupLogs;

  const ZSLogItemWidget({
    super.key,
    required this.group,
    required this.isNarrow,
    required this.isCompactPhone,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelected,
    this.onLongPress,
    required this.onDelete,
    required this.onCopy,
    required this.onShare,
    required this.formatGroupLogs,
  });

  @override
  State<ZSLogItemWidget> createState() => _ZSLogItemWidgetState();
}

class _ZSLogItemWidgetState extends State<ZSLogItemWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final groupColor = LogUIUtils.getGroupColor(widget.group);
    final cardRadius = BorderRadius.circular(
      widget.isCompactPhone ? 12 : 14,
    );

    return GestureDetector(
      onLongPress: widget.onLongPress ??
          () {
            widget.onDelete(widget.group);
          },
      onTap: widget.isSelectionMode ? widget.onSelected : null,
      child: Container(
        margin: EdgeInsets.only(
          bottom: widget.isCompactPhone ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? groupColor.withValues(alpha: 0.12)
              : const Color(0xFF15191C),
          borderRadius: cardRadius,
          border: Border.all(
            color: widget.isSelected
                ? groupColor
                : groupColor.withValues(alpha: 0.28),
            width: widget.isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IgnorePointer(
          ignoring: widget.isSelectionMode,
          child: Theme(
            data: Theme.of(context).copyWith(
              hoverColor: Colors.white.withValues(alpha: 0.05),
              splashColor: groupColor.withValues(alpha: 0.12),
            ),
            child: ExpansionTile(
              backgroundColor: const Color(0xFF1C1F22),
              collapsedBackgroundColor: Colors.transparent,
              tilePadding: EdgeInsets.symmetric(
                horizontal: widget.isCompactPhone ? 10 : 14,
                vertical: widget.isCompactPhone ? 8 : 6,
              ),
              childrenPadding: EdgeInsets.fromLTRB(
                widget.isCompactPhone ? 10 : 12,
                4,
                widget.isCompactPhone ? 10 : 12,
                10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: cardRadius,
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: cardRadius,
              ),
              leading: widget.isSelectionMode
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isSelected
                              ? groupColor
                              : Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        color: widget.isSelected
                            ? groupColor
                            : Colors.transparent,
                      ),
                      child: widget.isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.black,
                            )
                          : null,
                    )
                  : (widget.isNarrow
                      ? null
                      : Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: groupColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            LogUIUtils.getMethodIcon(widget.group.method),
                            color: groupColor,
                            size: 20,
                          ),
                        )),
            title: widget.isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  groupColor.withValues(alpha: 0.28),
                                  groupColor.withValues(alpha: 0.06),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: groupColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LogUIUtils.getMethodIcon(widget.group.method),
                                  size: 14,
                                  color: groupColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.group.method.toUpperCase(),
                                  style: TextStyle(
                                    color: groupColor,
                                    fontFamily: 'JetBrainsMono',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (widget.group.statusCode != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: groupColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: groupColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '${widget.group.statusCode}',
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
                        widget.group.uri,
                        style: TextStyle(
                          color: groupColor.withValues(alpha: 0.95),
                          fontFamily: 'JetBrainsMono',
                          fontSize: widget.isCompactPhone ? 11.5 : 12,
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
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              groupColor.withValues(alpha: 0.25),
                              groupColor.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: groupColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.group.method.toUpperCase(),
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
                          widget.group.uri,
                          maxLines: 2,
                          style: TextStyle(
                            color: groupColor,
                            fontFamily: 'JetBrainsMono',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.group.statusCode != null &&
                          widget.group.statusCode != 0)
                        Container(
                          margin: const EdgeInsets.only(left: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: groupColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: groupColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '${widget.group.statusCode}',
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
              child: Row(
                children: [
                  Text(
                    LogUIUtils.formatTimestamp(widget.group.timestamp),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontFamily: 'JetBrainsMono',
                      fontSize: widget.isCompactPhone ? 10 : 11,
                    ),
                  ),
                  if (widget.group.duration != null ||
                      widget.group.responseSize != null) ...[
                    const SizedBox(width: 8),
                    const Text(
                      '•',
                      style: TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                    const SizedBox(width: 8),
                    if (widget.group.duration != null)
                      Text(
                        '${widget.group.duration}ms',
                        style: TextStyle(
                          color: LogUIUtils.getDurationColor(
                              widget.group.duration),
                          fontFamily: 'JetBrainsMono',
                          fontSize: widget.isCompactPhone ? 10 : 11,
                        ),
                      ),
                    if (widget.group.duration != null &&
                        widget.group.responseSize != null)
                      const SizedBox(width: 8),
                    if (widget.group.responseSize != null)
                      Text(
                        LogUIUtils.formatSize(widget.group.responseSize),
                        style: TextStyle(
                          color: LogUIUtils.getSizeColor(
                              widget.group.responseSize),
                          fontFamily: 'JetBrainsMono',
                          fontSize: widget.isCompactPhone ? 10 : 11,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            children: [
              // Quick actions
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: 'Copy all entries in this group',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onCopy(
                            widget.formatGroupLogs(widget.group),
                            'Log group',
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: groupColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: groupColor.withValues(alpha: 0.28)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy, size: 14, color: groupColor),
                                const SizedBox(width: 6),
                                Text(
                                  'Copy All',
                                  style: TextStyle(
                                    color: groupColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'JetBrainsMono',
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
                          onTap: () => widget.onShare(
                            widget.formatGroupLogs(widget.group),
                            'Log Group: ${widget.group.method} ${widget.group.uri}',
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: groupColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: groupColor.withValues(alpha: 0.28)),
                            ),
                            child: Icon(Icons.share_rounded,
                                size: 14, color: groupColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'View full details with search',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => LogDetailsScreen(
                                  group: widget.group,
                                  onCopy: widget.onCopy,
                                  onShare: widget.onShare,
                                  formatGroupLogs: widget.formatGroupLogs,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: groupColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: groupColor.withValues(alpha: 0.28)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fullscreen_rounded,
                                    size: 14, color: groupColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Details',
                                  style: TextStyle(
                                    color: groupColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'JetBrainsMono',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Individual log entries
              ...widget.group.entries.map((entry) {
                final color = LogUIUtils.getLogColor(entry);
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Log Type Icon
                      Container(
                        margin: const EdgeInsets.only(top: 2, right: 12),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LogUIUtils.getLogTypeIcon(entry.type),
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
                          onTap: () => widget.onCopy(
                            entry.message,
                            'Log entry',
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: EdgeInsets.all(
                              widget.isCompactPhone ? 10 : 6,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.copy_rounded,
                              size: widget.isCompactPhone ? 18 : 16,
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
                          onTap: () => widget.onShare(
                            entry.message,
                            'Log Entry: ${widget.group.method}',
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: EdgeInsets.all(
                              widget.isCompactPhone ? 10 : 6,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.share_rounded,
                              size: widget.isCompactPhone ? 18 : 16,
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
    ),
  );
}
}
