/// The input area widget at the bottom of the chat screen.
///
/// Provides an expandable text field, attachment button, send button
/// with gradient background, optional voice input button, and a
/// character count indicator. Supports canceling an in-flight stream.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/app_constants.dart';
import '../../../../theme/zephyr_theme.dart';

/// The chat input bar shown at the bottom of the chat screen.
class ChatInputArea extends StatefulWidget {
  /// Called when the user sends a message with the given [text].
  final ValueChanged<String> onSend;

  /// Called when the attachment button is tapped.
  final VoidCallback? onAttachment;

  /// Called when the voice input button is tapped.
  final VoidCallback? onVoiceInput;

  /// Whether a response is currently being streamed.
  final bool isStreaming;

  /// Called to cancel an in-flight streaming response.
  final VoidCallback? onCancelStreaming;

  const ChatInputArea({
    super.key,
    required this.onSend,
    this.onAttachment,
    this.onVoiceInput,
    this.isStreaming = false,
    this.onCancelStreaming,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Maximum number of lines the text field can expand to.
  static const int _maxLines = 4;

  /// Maximum character count before the indicator turns red.
  static const int _maxChars = 4000;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Sends the current text and clears the field.
  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    widget.onSend(text);
    _controller.clear();

    // Keep focus so the user can continue typing.
    _focusNode.requestFocus();
  }

  /// Handles the send action from the keyboard (on pressing Enter).
  void _handleSubmitted(String text) {
    // Only send on explicit Enter (not newline).
    if (text.contains('\n')) {
      // Allow multi-line — don't send yet.
      return;
    }
    _handleSend();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        UIConstants.spacingMd,
        UIConstants.spacingSm,
        UIConstants.spacingMd,
        MediaQuery.of(context).padding.bottom + UIConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: ZephyrColors.bgPrimary,
        border: Border(
          top: BorderSide(
            color: ZephyrColors.divider.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Character count indicator.
          if (_controller.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_controller.text.length}/$_maxChars',
                  style: TextStyle(
                    fontSize: 11,
                    color: _controller.text.length > _maxChars
                        ? ZephyrColors.error
                        : ZephyrColors.textMuted,
                  ),
                ),
              ),
            ),

          // Input row.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Attachment button ──────────────────────────────────
              if (!widget.isStreaming)
                _IconButton(
                  icon: Icons.attach_file_rounded,
                  tooltip: 'Attach file',
                  onTap: widget.onAttachment,
                )
              else
                _IconButton(
                  icon: Icons.attach_file_rounded,
                  tooltip: 'Attachments disabled during streaming',
                  onTap: null,
                  disabled: true,
                ),

              const SizedBox(width: 8),

              // ── Text field ─────────────────────────────────────────
              Expanded(
                child: _buildTextField(),
              ),

              const SizedBox(width: 8),

              // ── Send / Cancel button ───────────────────────────────
              if (widget.isStreaming && widget.onCancelStreaming != null)
                _buildCancelButton()
              else
                _buildSendButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return AnimatedContainer(
      duration: UIConstants.animationShort,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: ZephyrColors.bgTertiary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _focusNode.hasFocus
              ? ZephyrColors.accentPurple
              : ZephyrColors.divider.withOpacity(0.5),
          width: _focusNode.hasFocus ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: !widget.isStreaming,
        maxLines: _maxLines,
        minLines: 1,
        textInputAction: TextInputAction.newline,
        onSubmitted: _handleSubmitted,
        style: const TextStyle(
          color: ZephyrColors.textPrimary,
          fontSize: 15,
          height: 1.4,
        ),
        decoration: InputDecoration(
          hintText: widget.isStreaming
              ? 'Waiting for response…'
              : 'Ask anything…',
          hintStyle: TextStyle(
            color: ZephyrColors.textMuted,
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          suffixIcon: _buildSuffixIcon(),
        ),
        inputFormatters: [
          LengthLimitingTextInputFormatter(_maxChars * 2),
        ],
      ),
    );
  }

  /// Shows a voice input icon inside the text field when the field is not
  /// focused, or a clear button when there is text.
  Widget? _buildSuffixIcon() {
    if (_controller.text.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.close_rounded, size: 18),
        color: ZephyrColors.textMuted,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        onPressed: () {
          _controller.clear();
          _focusNode.requestFocus();
        },
      );
    }

    if (widget.onVoiceInput != null && !_focusNode.hasFocus) {
      return IconButton(
        icon: const Icon(Icons.mic_rounded, size: 20),
        color: ZephyrColors.textMuted,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        onPressed: widget.onVoiceInput,
        tooltip: 'Voice input',
      );
    }

    return null;
  }

  Widget _buildSendButton() {
    final hasText = _controller.text.trim().isNotEmpty;

    return GestureDetector(
      onTap: hasText ? _handleSend : null,
      child: AnimatedContainer(
        duration: UIConstants.animationShort,
        curve: Curves.easeOutCubic,
        width: hasText ? 44 : 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: hasText
              ? zephyrPrimaryGradient
              : null,
          color: hasText ? null : ZephyrColors.bgTertiary,
          boxShadow: hasText
              ? [
                  BoxShadow(
                    color: ZephyrColors.accentPurple.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          hasText ? Icons.send_rounded : Icons.mic_rounded,
          color: hasText ? Colors.white : ZephyrColors.textMuted,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return GestureDetector(
      onTap: widget.onCancelStreaming,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ZephyrColors.error.withOpacity(0.15),
          border: Border.all(
            color: ZephyrColors.error.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.stop_rounded,
          color: ZephyrColors.error,
          size: 22,
        ),
      ),
    );
  }
}

/// A simple icon button with consistent styling.
class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool disabled;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ZephyrColors.bgTertiary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ZephyrColors.divider.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: disabled
                ? ZephyrColors.textMuted.withOpacity(0.4)
                : ZephyrColors.textSecondary,
          ),
        ),
      ),
    );
  }
}