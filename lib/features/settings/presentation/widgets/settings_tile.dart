/// A reusable settings list tile with a leading icon, title, subtitle,
/// and optional trailing widget (toggle, switch, or icon).
library;

import 'package:flutter/material.dart';

import '../../../../core/utils/app_constants.dart';
import '../../../../theme/zephyr_theme.dart';

/// A styled list tile for settings entries.
///
/// Supports a leading icon, title, subtitle, trailing widget, and
/// optional tap handler. When [isDestructive] is true, the title
/// renders in the error color.
class SettingsTile extends StatelessWidget {
  /// Leading icon displayed before the title.
  final IconData leading;

  /// Primary label text.
  final String title;

  /// Secondary descriptive text.
  final String? subtitle;

  /// Trailing widget — typically a [Switch], [Icon], or [Slider].
  final Widget? trailing;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  /// When true, renders the title in the error color for destructive
  /// actions (e.g. "Clear All Data").
  final bool isDestructive;

  const SettingsTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDestructive
              ? ZephyrColors.error.withOpacity(0.12)
              : ZephyrColors.accentPurple.withOpacity(0.12),
          borderRadius: BorderRadius.circular(UIConstants.radiusSm),
        ),
        child: Icon(
          leading,
          color: isDestructive
              ? ZephyrColors.error
              : ZephyrColors.accentPurpleLight,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive
              ? ZephyrColors.error
              : ZephyrColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                color: ZephyrColors.textMuted,
                fontSize: 13,
              ),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(
                  Icons.chevron_right_rounded,
                  color: ZephyrColors.textMuted,
                  size: 20,
                )
              : null),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: UIConstants.spacingMd,
        vertical: 2,
      ),
      minVerticalPadding: 8,
    );
  }
}