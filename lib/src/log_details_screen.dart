import 'package:flutter/material.dart';

import 'models/request_log_group.dart';
import 'utils/log_ui_utils.dart';

class LogDetailsScreen extends StatefulWidget {
  final ZSRequestLogGroup group;
  final Function(String, String) onCopy;
  final Function(String, String) onShare;
  final String Function(ZSRequestLogGroup) formatGroupLogs;

  const LogDetailsScreen({
    super.key,
    required this.group,
    required this.onCopy,
    required this.onShare,
    required this.formatGroupLogs,
  });

  @override
  State<LogDetailsScreen> createState() => _LogDetailsScreenState();
}

class _LogDetailsScreenState extends State<LogDetailsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TextSpan> _highlightSearch(String text, String query, Color entryColor) {
    if (query.isEmpty)
      return [TextSpan(text: text, style: TextStyle(color: entryColor))];

    final matches =
        RegExp(RegExp.escape(query), caseSensitive: false).allMatches(text);
    if (matches.isEmpty)
      return [TextSpan(text: text, style: TextStyle(color: entryColor))];

    final spans = <TextSpan>[];
    int lastMatchEnd = 0;
    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(color: entryColor),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: const TextStyle(
          backgroundColor: Colors.yellow,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(color: entryColor),
      ));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final groupColor = LogUIUtils.getGroupColor(widget.group);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        leading: IconButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group.method.toUpperCase(),
              style: TextStyle(
                color: groupColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'JetBrainsMono',
              ),
            ),
            Text(
              widget.group.uri,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'JetBrainsMono',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Tooltip(
            message: 'Copy all',
            child: IconButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.transparent),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => widget.onCopy(
                widget.formatGroupLogs(widget.group),
                'Log group',
              ),
            ),
          ),
          Tooltip(
            message: 'Share all',
            child: IconButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.transparent),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              icon: const Icon(Icons.share_rounded, size: 18),
              onPressed: () => widget.onShare(
                widget.formatGroupLogs(widget.group),
                'Log Group: ${widget.group.method} ${widget.group.uri}',
              ),
            ),
          ),
          if (widget.group.statusCode != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: groupColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: groupColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${widget.group.statusCode}',
                    style: TextStyle(
                      color: groupColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              autocorrect: false,
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search within logs...',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white24, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.all(Colors.transparent),
                          foregroundColor:
                              WidgetStateProperty.all(Colors.white24),
                        ),
                        icon: const Icon(Icons.clear,
                            color: Colors.white24, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF161B22),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: groupColor.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              itemCount: widget.group.entries.length,
              itemBuilder: (context, index) {
                final entry = widget.group.entries[index];
                final color = LogUIUtils.getLogColor(entry);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LogUIUtils.getLogTypeIcon(entry.type),
                              size: 14, color: color),
                          const SizedBox(width: 8),
                          Text(
                            entry.type.toString().split('.').last.toUpperCase(),
                            style: TextStyle(
                              color: color.withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            LogUIUtils.formatTimestamp(entry.timestamp),
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: _highlightSearch(
                                    entry.message, _searchQuery, color),
                                style: const TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.all(
                                      color.withValues(alpha: 0.1)),
                                  foregroundColor:
                                      WidgetStateProperty.all(color),
                                  padding:
                                      WidgetStateProperty.all(EdgeInsets.zero),
                                  minimumSize: WidgetStateProperty.all(
                                      const Size(32, 32)),
                                ),
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                onPressed: () =>
                                    widget.onCopy(entry.message, 'Log entry'),
                              ),
                              IconButton(
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.all(
                                      color.withValues(alpha: 0.1)),
                                  foregroundColor:
                                      WidgetStateProperty.all(color),
                                  padding:
                                      WidgetStateProperty.all(EdgeInsets.zero),
                                  minimumSize: WidgetStateProperty.all(
                                      const Size(32, 32)),
                                ),
                                icon: const Icon(Icons.share_rounded, size: 16),
                                onPressed: () => widget.onShare(entry.message,
                                    'Log Entry: ${widget.group.method}'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
