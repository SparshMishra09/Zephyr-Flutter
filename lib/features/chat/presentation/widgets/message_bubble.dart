/// A chat message bubble widget.
///
/// Renders differently for user vs assistant messages, supports
/// streaming cursor animation, source citation chips, markdown-like
/// formatting (code blocks, bold), timestamps, and long-press context
/// menus for copy/delete.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/message_model.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../theme/zephyr_theme.dart';
import 'source_citation_chip.dart';

/// A single chat message displayed as a bubble.
class MessageBubble extends StatelessWidget {
  /// The message data.
  final MessageModel message;

  /// Whether the message is currently being streamed in.
  final bool isStreaming;

  /// Called when the user requests to copy the message text.
  final VoidCallback onCopy;

  /// Called when the user requests to delete the message.
  final VoidCallback onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    required this.onCopy,
    required this.onDelete,
  });

  /// Formats a [DateTime] into a short time string (e.g. "3:45 PM").
  String _formatTime(DateTime date) {
    return DateFormat.jm().format(date);
  }

  /// Shows a long-press context menu with Copy and Delete actions.
  Future<void> _showContextMenu(BuildContext context) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Position? position = context.findRenderObject() as Position?;

    if (position == null) return;

    final Offset tapPosition = position.localToGlobal(Offset.zero, anchor: overlay);

    return showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        tapPosition.dx,
        tapPosition.dy,
      ),
      items: [
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 18, color: ZephyrColors.textSecondary),
              SizedBox(width: 12),
              Text('Copy'),
            ],
          ),
        ),
        if (message.role == MessageRole.user)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 18, color: ZephyrColors.error),
                SizedBox(width: 12),
                Text('Delete', style: TextStyle(color: ZephyrColors.error)),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: message.content));
        onCopy();
      } else if (value == 'delete') {
        onDelete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Assistant avatar (left side only) ────────────────────
            if (!isUser) ...[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: zephyrPrimaryGradient,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
            ],

            // ── Bubble ───────────────────────────────────────────────
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Timestamp (above bubble).
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: ZephyrColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Bubble content.
                  _buildBubble(context, isUser),

                  // Source citations (assistant only).
                  if (!isUser && message.sources.isNotEmpty && !isStreaming) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: SourceCitationChip(
                        sourceIds: message.sources,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Spacer for user side ─────────────────────────────────
            if (isUser) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context, bool isUser) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width *
            UIConstants.chatBubbleMaxWidth,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _buildBubbleDecoration(isUser),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message text with markdown-like formatting.
          _buildMessageText(isUser),

          // Streaming cursor.
          if (isStreaming) ...[
            const SizedBox(height: 4),
            const _StreamingCursor(),
          ],
        ],
      ),
    );
  }

  BoxDecoration _buildBubbleDecoration(bool isUser) {
    if (isUser) {
      return BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ZephyrColors.accentPurple,
            ZephyrColors.accentBlue,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: ZephyrColors.accentPurple.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }

    return BoxDecoration(
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
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  Widget _buildMessageText(bool isUser) {
    final text = message.content;

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    // Simple markdown-like parsing: detect code blocks and bold text.
    return _MarkdownFormattedText(
      text: text,
      textColor: isUser ? Colors.white : ZephyrColors.textPrimary,
      codeBlockBg: isUser
          ? Colors.white.withOpacity(0.15)
          : ZephyrColors.bgTertiary,
    );
  }
}

// ── Streaming cursor ──────────────────────────────────────────────────

class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 16,
        decoration: BoxDecoration(
          color: ZephyrColors.accentPurpleLight,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ── Markdown-formatted text ───────────────────────────────────────────

/// A simple widget that renders markdown-like formatting:
///
/// * Code blocks (triple backticks) → monospace, dark background
/// * Bold text (`**text**`) → bold weight
/// * Inline code (single backticks) → monospace, pill background
///
/// This is intentionally lightweight and not a full markdown parser.
class _MarkdownFormattedText extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color codeBlockBg;

  const _MarkdownFormattedText({
    required this.text,
    required this.textColor,
    required this.codeBlockBg,
  });

  @override
  Widget build(BuildContext context) {
    // Check for code blocks first.
    final codeBlockRegex = RegExp(r'```([\s\S]*?)```');
    final matches = codeBlockRegex.allMatches(text);

    if (matches.isEmpty) {
      // No code blocks — render inline formatting only.
      return _buildInlineFormattedText(text);
    }

    // Render segments: text before/after/between code blocks.
    final widgets = <Widget>[];
    var lastEnd = 0;

    for (final match in matches) {
      // Text before this code block.
      if (match.start > lastEnd) {
        final beforeText = text.substring(lastEnd, match.start);
        widgets.add(_buildInlineFormattedText(beforeText));
      }

      // Code block.
      final codeContent = match.group(1)?.trim() ?? '';
      widgets.add(
        const SizedBox(height: 6),
      );
      widgets.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: codeBlockBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ZephyrColors.divider.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: SelectableText(
            codeContent,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: ZephyrColors.accentPurpleLight,
              height: 1.5,
            ),
          ),
        ),
      );

      widgets.add(const SizedBox(height: 4));
      lastEnd = match.end;
    }

    // Text after the last code block.
    if (lastEnd < text.length) {
      widgets.add(_buildInlineFormattedText(text.substring(lastEnd)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Renders text with inline bold (`**text**`) and inline code (`` `text` ``).
  Widget _buildInlineFormattedText(String text) {
    // Split by bold markers first.
    final parts = text.split('**');

    if (parts.length <= 1) {
      // No bold markers — check for inline code.
      return _buildInlineCodeText(text);
    }

    final textSpans = <TextSpan>[];

    for (var i = 0; i < parts.length; i++) {
      final segment = parts[i];
      final isBold = (i % 2 == 1);

      if (isBold) {
        textSpans.add(
          TextSpan(
            text: segment,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        );
      } else {
        // Parse inline code within normal text.
        textSpans.addAll(_buildInlineCodeSpans(segment, textColor));
      }
    }

    return RichText(
      text: TextSpan(
        children: textSpans,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  /// Splits text by inline code backticks and returns TextSpans.
  List<TextSpan> _buildInlineCodeSpans(String text, Color color) {
    final spans = <TextSpan>[];
    final codeRegex = RegExp(r'`([^`]+)`');
    final matches = codeRegex.allMatches(text);

    if (matches.isEmpty) {
      spans.add(TextSpan(text: text));
      return spans;
    }

    var lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(
            fontFamily: 'monospace',
            backgroundColor: Color(0x207C3AED),
            fontSize: 13,
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }

  Widget _buildInlineCodeText(String text) {
    final codeRegex = RegExp(r'`([^`]+)`');
    if (!codeRegex.hasMatch(text)) {
      return Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          height: 1.5,
        ),
      );
    }

    return _buildInlineFormattedText(text);
  }
}