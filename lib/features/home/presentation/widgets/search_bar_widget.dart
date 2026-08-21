/// A custom search bar widget for the Zephyr home screen.
///
/// Features a rounded dark input field with a leading search icon,
/// a trailing voice-input button, and an auto-appearing clear button
/// when text is entered.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/zephyr_theme.dart';

class SearchBarWidget extends StatefulWidget {
  /// Callback invoked when the user submits a search query.
  final ValueChanged<String> onSearch;

  /// Callback invoked when the voice input button is tapped.
  final VoidCallback onVoiceInput;

  /// Placeholder hint text.
  final String hintText;

  const SearchBarWidget({
    super.key,
    required this.onSearch,
    required this.onVoiceInput,
    this.hintText = 'Ask Zephyr anything…',
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSubmitted(String value) {
    final query = value.trim();
    if (query.isNotEmpty) {
      _focusNode.unfocus();
      widget.onSearch(query);
    }
  }

  void _onClear() {
    _textController.clear();
    _focusNode.requestFocus();
  }

  void _onVoiceTap() {
    // Haptic feedback for tactile response.
    HapticFeedback.lightImpact();
    widget.onVoiceInput();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: ZephyrColors.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focusNode.hasFocus
              ? ZephyrColors.accentPurple.withOpacity(0.6)
              : ZephyrColors.divider.withOpacity(0.5),
          width: _focusNode.hasFocus ? 1.5 : 1,
        ),
        boxShadow: _focusNode.hasFocus
            ? [
                BoxShadow(
                  color: ZephyrColors.accentPurple.withOpacity(0.1),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: _onSubmitted,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ZephyrColors.textPrimary,
              fontSize: 14,
            ),
        cursorColor: ZephyrColors.accentPurpleLight,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ZephyrColors.textMuted,
                fontSize: 14,
              ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: ZephyrColors.textMuted,
            size: 20,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          suffixIcon: _buildSuffixIcons(),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 12,
          ),
          isDense: true,
        ),
      ),
    );
  }

  /// Builds the trailing icon buttons: clear (conditional) + voice input.
  Widget _buildSuffixIcons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Vertical divider between text area and buttons.
        Container(
          width: 1,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: ZephyrColors.divider.withOpacity(0.5),
        ),
        // Clear button — shown only when there is text.
        if (_textController.text.isNotEmpty)
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: ZephyrColors.textMuted,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _onClear,
            tooltip: 'Clear',
          ),
        // Voice input button.
        IconButton(
          icon: Icon(
            Icons.mic_rounded,
            size: 20,
            color: ZephyrColors.accentPurpleLight,
          ),
          padding: const EdgeInsets.only(right: 4),
          constraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          onPressed: _onVoiceTap,
          tooltip: 'Voice input',
        ),
      ],
    );
  }
}