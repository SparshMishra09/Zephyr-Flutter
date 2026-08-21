/// A list-tile widget displaying a single recent conversation.
///
/// Shows the conversation title, a text preview of the last message,
/// and a relative timestamp. Designed to be wrapped in a [Dismissible]
/// for swipe-to-delete support.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/conversation_model.dart';
import '../../../../theme/zephyr_theme.dart';

class ConversationTile extends StatelessWidget {
  /// The conversation data to display.
  final ConversationModel conversation;

  /// Callback invoked when the tile is tapped.
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  /// Formats a [DateTime] into a human-friendly relative string.
  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      // Today — show time.
      return DateFormat.jm().format(date);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat.E().format(date);
    } else if (diff.inDays < 30) {
      return DateFormat.MMMd().format(date);
    } else {
      return DateFormat.yMMMd().format(date);
    }
  }

  /// Generates a preview snippet from the conversation title.
  ///
  /// In a real app this would use the last message content; here we
  /// use the title as a stand-in.
  String _previewText() {
    const maxLength = 60;
    final text = conversation.title;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}…';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: ZephyrColors.bgSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ZephyrColors.divider.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              // ── Left icon ──────────────────────────────────────────
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ZephyrColors.accentPurple.withOpacity(0.15),
                      ZephyrColors.accentBlue.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  conversation.isPinned
                      ? Icons.push_pin_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: ZephyrColors.accentPurpleLight,
                ),
              ),
              const SizedBox(width: 12),

              // ── Text content ───────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                              color: ZephyrColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.isPinned)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ZephyrColors.accentPurple
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Pinned',
                              style: TextStyle(
                                color: ZephyrColors.accentPurpleLight,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Preview text.
                    Text(
                      _previewText(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ZephyrColors.textMuted,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ── Timestamp ──────────────────────────────────────────
              const SizedBox(width: 8),
              Text(
                _formatTimestamp(conversation.updatedAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ZephyrColors.textMuted,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}