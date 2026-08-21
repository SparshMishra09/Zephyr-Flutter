/// The Chat screen for Zephyr.
///
/// Displays a conversation thread with message bubbles, a streaming
/// typing indicator, and an input area at the bottom. Supports
/// pull-to-refresh, long-press context menus, and smooth auto-scroll.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../../../core/models/message_model.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../theme/zephyr_theme.dart';
import '../viewmodels/chat_viewmodel.dart';
import '../widgets/chat_input_area.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';

/// Navigates to the chat screen for a given [conversationId].
///
/// If [conversationId] is null, a new conversation is created automatically.
class ChatScreen extends StatefulWidget {
  /// The ID of the conversation to open. If null, a new one is created.
  final String? conversationId;

  const ChatScreen({super.key, this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final _refreshController = RefreshController();

  @override
  void initState() {
    super.initState();
    // Initialise the view model once the build context is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initViewModel();
    });
  }

  Future<void> _initViewModel() async {
    if (!mounted) return;

    final vm = context.read<ChatViewModel>();

    if (widget.conversationId != null) {
      await vm.init(widget.conversationId!);
    } else {
      final newId = await vm.createNewConversation();
      // Update the route so the back-navigation works correctly.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => ChatScreen(conversationId: newId),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  /// Smoothly scrolls to the bottom of the message list.
  void _scrollToBottom() {
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: UIConstants.animationMedium,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZephyrColors.bgPrimary,
      appBar: _buildAppBar(),
      body: Consumer<ChatViewModel>(
        builder: (context, vm, _) {
          // Scroll to bottom whenever messages change.
          if (vm.messages.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          }

          if (vm.isLoading) {
            return const _LoadingState();
          }

          return Column(
            children: [
              // ── Error banner ───────────────────────────────────────
              if (vm.errorMessage != null)
                _buildErrorBanner(vm),

              // ── Message list ───────────────────────────────────────
              Expanded(
                child: vm.messages.isEmpty && !vm.isStreaming
                    ? _buildEmptyState()
                    : SmartRefresher(
                        enablePullDown: true,
                        controller: _refreshController,
                        onRefresh: () async {
                          if (vm.currentConversation != null) {
                            await vm.loadConversation(
                                vm.currentConversation!.id);
                          }
                          _refreshController.refreshCompleted();
                        },
                        header: const WaterDropHeader(
                          waterDropColor: ZephyrColors.accentPurple,
                          backgroundColor: ZephyrColors.bgPrimary,
                        ),
                        child: _buildMessageList(vm),
                      ),
              ),

              // ── Input area ─────────────────────────────────────────
              ChatInputArea(
                onSend: (text) {
                  vm.sendMessage(text);
                  // Scroll after a short delay to let the message appear.
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _scrollToBottom();
                  });
                },
                onAttachment: () {
                  // TODO: integrate file picker with the RAG ingestion pipeline.
                  debugPrint('Attachment tapped');
                },
                onVoiceInput: () {
                  // TODO: integrate voice-to-text.
                  debugPrint('Voice input tapped');
                },
                isStreaming: vm.isStreaming,
                onCancelStreaming: vm.cancelStreaming,
              ),
            ],
          );
        },
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return Consumer<ChatViewModel>(
      builder: (context, vm, _) {
        final title = vm.currentConversation?.title ?? 'New Chat';

        return AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
          ),
          title: Row(
            children: [
              // Avatar / icon.
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: zephyrPrimaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              // Title + subtitle.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ZephyrColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      vm.messages.length > 0
                          ? '${vm.messages.length} messages'
                          : 'Start a conversation',
                      style: TextStyle(
                        fontSize: 12,
                        color: ZephyrColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Edit title button.
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showEditTitleDialog(vm),
              tooltip: 'Edit title',
            ),
            // More actions.
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 22),
              onSelected: (value) {
                if (value == 'delete' && vm.currentConversation != null) {
                  _confirmDeleteConversation(vm);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          color: ZephyrColors.error, size: 20),
                      SizedBox(width: 12),
                      Text('Delete conversation'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ── Error Banner ───────────────────────────────────────────────────

  Widget _buildErrorBanner(ChatViewModel vm) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
          horizontal: UIConstants.spacingMd, vertical: UIConstants.spacingSm),
      padding: const EdgeInsets.symmetric(
          horizontal: UIConstants.spacingMd,
          vertical: UIConstants.spacingSm),
      decoration: BoxDecoration(
        color: ZephyrColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusMd),
        border: Border.all(
            color: ZephyrColors.error.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: ZephyrColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              vm.errorMessage!,
              style: const TextStyle(
                  color: ZephyrColors.error, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: ZephyrColors.textMuted, size: 18),
            onPressed: vm.clearError,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    ).animate(
      effects: const [
        FadeEffect(duration: Duration(milliseconds: 200)),
        MoveEffect(
            begin: Offset(0, -10),
            duration: Duration(milliseconds: 200),
            curve: Curves.easeOutCubic),
      ],
    );
  }

  // ── Empty state ────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ZephyrColors.accentPurple.withOpacity(0.2),
                  ZephyrColors.accentBlue.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 36,
              color: ZephyrColors.accentPurpleLight,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start a new conversation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: ZephyrColors.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ask anything about your documents',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ZephyrColors.textMuted,
                ),
          ),
        ],
      ).animate(
        effects: const [
          FadeEffect(duration: Duration(milliseconds: 400)),
          MoveEffect(
              duration: Duration(milliseconds: 400),
              curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  // ── Message list ───────────────────────────────────────────────────

  Widget _buildMessageList(ChatViewModel vm) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
          horizontal: UIConstants.spacingMd,
          vertical: UIConstants.spacingSm),
      itemCount: vm.messages.length + (vm.isStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        // Handle streaming indicator at the end.
        if (vm.isStreaming && index == vm.messages.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: TypingIndicator(),
          ).animate(
            effects: const [
              FadeEffect(duration: Duration(milliseconds: 200)),
            ],
          );
        }

        final message = vm.messages[index];
        final isUser = message.role == MessageRole.user;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MessageBubble(
            message: message,
            isStreaming: message.isStreaming,
            onCopy: () => _copyMessage(message.content),
            onDelete: () => vm.deleteMessage(message.id),
          ),
        ).animate(
          delay: (index.clamp(0, 10) * 50).ms,
          effects: const [
            FadeEffect(duration: Duration(milliseconds: 250)),
            MoveEffect(
                begin: Offset(0, 12),
                duration: Duration(milliseconds: 250),
                curve: Curves.easeOutCubic),
          ],
        );
      },
    );
  }

  // ── Actions ────────────────────────────────────────────────────────

  void _copyMessage(String text) {
    // In a real app, use Clipboard.setData. For now, show a snackbar.
    debugPrint('Copied: $text');
  }

  Future<void> _showEditTitleDialog(ChatViewModel vm) async {
    if (vm.currentConversation == null) return;

    final controller = TextEditingController(
        text: vm.currentConversation!.title);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(
            hintText: 'Conversation title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      await vm.updateConversationTitle(result.trim());
    }
  }

  Future<void> _confirmDeleteConversation(ChatViewModel vm) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Conversation'),
            content: const Text(
                'Are you sure you want to delete this conversation? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: ZephyrColors.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && vm.currentConversation != null) {
      // TODO: implement deleteConversation on ChatViewModel or delegate to HomeViewModel.
      debugPrint('Deleting conversation: ${vm.currentConversation!.id}');
      Navigator.of(context).maybePop();
    }
  }
}

// ── Loading state ────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: ZephyrColors.accentPurple,
            strokeWidth: 2.5,
          ),
          SizedBox(height: 16),
          Text(
            'Loading conversation…',
            style: TextStyle(
              color: ZephyrColors.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}