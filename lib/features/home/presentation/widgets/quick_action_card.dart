/// A compact card widget representing a single quick action on the
/// Zephyr home screen.
///
/// Displays an icon, title, subtitle, and responds to taps with a
/// subtle scale animation.
library;

import 'package:flutter/material.dart';

import '../../../../theme/zephyr_theme.dart';

class QuickActionCard extends StatefulWidget {
  /// The icon displayed at the top of the card.
  final IconData icon;

  /// Primary label shown in bold.
  final String title;

  /// Secondary description shown in muted text.
  final String subtitle;

  /// Callback invoked when the card is tapped.
  final VoidCallback onTap;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<QuickActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!_isPressed) {
      _isPressed = true;
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (_isPressed) {
      _isPressed = false;
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (_isPressed) {
      _isPressed = false;
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ZephyrColors.bgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isPressed
                  ? ZephyrColors.accentPurple.withOpacity(0.4)
                  : ZephyrColors.divider.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? ZephyrColors.accentPurple.withOpacity(0.1)
                    : Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon container with gradient background.
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ZephyrColors.accentPurple.withOpacity(0.2),
                      ZephyrColors.accentBlue.withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: ZephyrColors.accentPurpleLight,
                ),
              ),
              const Spacer(),
              // Title.
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: ZephyrColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Subtitle.
              Text(
                widget.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ZephyrColors.textMuted,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}