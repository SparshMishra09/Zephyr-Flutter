/// Animated typing indicator widget.
///
/// Displays three pulsing dots that animate sequentially to indicate
/// that the assistant is composing a response.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/zephyr_theme.dart';

/// A typing indicator with three pulsing dots.
class TypingIndicator extends StatefulWidget {
  /// The color of the dots. Defaults to [ZephyrColors.accentPurpleLight].
  final Color dotColor;

  /// The size of each dot. Defaults to 8.0.
  final double dotSize;

  /// The spacing between dots. Defaults to 6.0.
  final double spacing;

  /// The duration of one pulse cycle. Defaults to 1.4 seconds.
  final Duration animationDuration;

  const TypingIndicator({
    super.key,
    this.dotColor = ZephyrColors.accentPurpleLight,
    this.dotSize = 8.0,
    this.spacing = 6.0,
    this.animationDuration = const Duration(milliseconds: 1400),
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ZephyrColors.bgSecondary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(
          color: ZephyrColors.divider.withOpacity(0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return _PulsingDot(
            color: widget.dotColor,
            size: widget.dotSize,
            controller: _controller,
            delay: index * 0.2,
          );
        }).separated(const SizedBox(width: 6)),
      ),
    );
  }
}

/// A single pulsing dot that scales and fades in/out.
class _PulsingDot extends AnimatedWidget {
  final Color color;
  final double size;
  final AnimationController controller;
  final double delay; // 0.0–1.0 offset into the cycle.

  const _PulsingDot({
    required this.color,
    required this.size,
    required this.controller,
    required this.delay,
  }) : super(listenable: controller);

  /// Computes the animation value for this dot, offset by [delay].
  double _value() {
    final phase = (controller.value + delay) % 1.0;
    // Smooth sine wave: 0 → 1 → 0.
    return (1 + math.sin(phase * 2 * math.pi)) / 2;
  }

  @override
  Widget build(BuildContext context) {
    final value = _value();
    return AnimatedContainer(
      duration: Duration.zero, // Driven by AnimatedWidget.
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withOpacity(0.3 + 0.7 * value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

