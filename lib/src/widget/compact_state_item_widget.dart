
import 'package:flutter/material.dart';

class ZSCompactStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  /// Tighter padding and type for narrow / phone layouts.
  final bool compact;

  /// When true, fills cross-axis (e.g. inside [Expanded] in a stats row).
  final bool stretch;

  const ZSCompactStatItem({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
    this.stretch = false,
  });

  @override
  Widget build(BuildContext context) {
    final dot = compact ? 6.0 : 8.0;
    final valueSize = compact ? 13.0 : 15.0;
    final labelSize = compact ? 9.0 : 10.0;
    final hPad = compact ? 8.0 : 10.0;
    final vPad = compact ? 6.0 : 4.0;

    final valueStyle = TextStyle(
      color: color,
      fontSize: valueSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: labelSize,
      letterSpacing: compact ? 0.4 : 0.6,
      fontWeight: FontWeight.w500,
    );

    final dotWidget = Container(
      width: dot,
      height: dot,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );

    Widget child;
    if (stretch && compact) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              dotWidget,
              const SizedBox(width: 6),
              Text(value, style: valueStyle),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
        ],
      );
    } else {
      child = Row(
        mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          dotWidget,
          SizedBox(width: compact ? 4 : 6),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: valueStyle,
            ),
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ],
      );
    }

    return Container(
      width: stretch ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
