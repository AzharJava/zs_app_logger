import 'package:flutter/material.dart';

// ===========================
// Fancy Expandable Widget
// ===========================
class FancyExpandableCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget content;
  final IconData icon;
  final List<Color> gradientColors;
  final double borderRadius;
  final Duration animationDuration;
  final VoidCallback? onLongPress;

  const FancyExpandableCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.content,
    required this.gradientColors,
    this.borderRadius = 20,
    this.animationDuration = const Duration(milliseconds: 400),
    this.onLongPress,
  });

  @override
  State<FancyExpandableCard> createState() => _FancyExpandableCardState();
}

class _FancyExpandableCardState extends State<FancyExpandableCard>
    with TickerProviderStateMixin {
  bool _isExpanded = false;

  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _iconRotation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.animationDuration);
    _expandAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _iconRotation = Tween<double>(begin: 0, end: 0.5).animate(_expandAnimation);
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: widget.animationDuration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isExpanded ? 0.15 : 0.08),
            blurRadius: _isExpanded ? 18 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Column(
          children: [
            InkWell(
              onTap: _toggle,
              onLongPress: widget.onLongPress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    RotationTransition(
                      turns: _iconRotation,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizeTransition(
              sizeFactor: _expandAnimation,
              axisAlignment: -1,
              child: FadeTransition(
                opacity: _expandAnimation,
                child: ScaleTransition(
                  scale: _expandAnimation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    color: Colors.white,
                    child: widget.content,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
