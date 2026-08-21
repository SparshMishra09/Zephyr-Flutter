/// A reusable onboarding page widget with an illustration area, title,
/// and description.
///
/// Used by each of the three onboarding pages to maintain consistent
/// layout and typography while allowing custom illustrations.
library;

import 'package:flutter/material.dart';

import '../../../../core/utils/app_constants.dart';
import '../../../../theme/zephyr_theme.dart';

/// A single onboarding page with illustration, title, and description.
///
/// The [illustrationBuilder] receives the available illustration area
/// size and should return a widget that fits within it.
class OnboardingPage extends StatelessWidget {
  /// Builder for the illustration area. Receives the available size.
  final Widget Function(double size) illustrationBuilder;

  /// The page title (typically 1–2 lines).
  final String title;

  /// The page description (typically 2–4 lines).
  final String description;

  const OnboardingPage({
    super.key,
    required this.illustrationBuilder,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final illustrationSize = screenSize.width * 0.7;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.spacingXl,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Illustration area ───────────────────────────────────
          SizedBox(
            width: illustrationSize,
            height: illustrationSize,
            child: illustrationBuilder(illustrationSize),
          ),

          const SizedBox(height: 48),

          // ── Title ──────────────────────────────────────────────
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: ZephyrColors.textPrimary,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 16),

          // ── Description ────────────────────────────────────────
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: ZephyrColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}