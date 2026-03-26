import 'package:flutter/material.dart';

class ZSAppLoggerSmallChipsWidget extends StatelessWidget {
  final List<Color> colors;
  final Color methodColor;
  final IconData methodIcon;
  final String method;
  final String value;
  const ZSAppLoggerSmallChipsWidget(
      {super.key, required this.colors, required this.methodColor, required this.methodIcon, required this.method, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: methodColor.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: methodColor.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: methodColor.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              methodIcon,
              size: 8,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${method.toUpperCase()} • $value',
            style: TextStyle(
              color: methodColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
