/// A section header widget for grouping settings tiles.
///
/// Displays a title and optional subtitle with consistent spacing
/// and typography used across the settings screen.
library;

import 'package:flutter/material.dart';

import '../../../../core/utils/app_constants.dart';
import '../../../../theme/zephyr_theme.dart';

/// A section header that groups related settings together.
class SettingsSection extends StatelessWidget {
  /// The section title (e.g. "API Configuration").
  final String title;

  /// Optional subtitle describing the section.
  final String? subtitle;

  const SettingsSection({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UIConstants.spacingMd,
        UIConstants.spacingLg,
        UIConstants.spacingMd,
        UIConstants.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZephyrColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                color: ZephyrColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}