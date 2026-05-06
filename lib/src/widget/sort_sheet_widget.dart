import 'package:flutter/material.dart';
import '../log_screen.dart';
import '../utils/log_ui_utils.dart';

class ZSSortBySheet extends StatelessWidget {
  final SortBy currentSortBy;
  final Function(SortBy) onSortSelected;

  const ZSSortBySheet({
    super.key,
    required this.currentSortBy,
    required this.onSortSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
                color: currentSortBy == s ? Colors.cyanAccent : Colors.white38,
              ),
              title: Text(
                LogUIUtils.sortLabel(s),
                style: TextStyle(
                  color: currentSortBy == s ? Colors.cyanAccent : Colors.white70,
                  fontWeight:
                      currentSortBy == s ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              trailing: currentSortBy == s
                  ? const Icon(Icons.check_rounded, color: Colors.cyanAccent)
                  : null,
              onTap: () {
                onSortSelected(s);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
