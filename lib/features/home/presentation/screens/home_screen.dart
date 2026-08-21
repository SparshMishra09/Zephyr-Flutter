/// The main home screen of the Zephyr application.
///
/// Displays a search bar, quick-action cards, recent conversations,
/// and a bottom navigation bar. Integrates the ghost bubble overlay.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../../../core/utils/app_constants.dart';
import '../../../../overlay/ghost_bubble_service.dart';
import '../../../../theme/zephyr_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/search_bar_widget.dart';

// ── Home screen ────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _refreshController = RefreshController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZephyrColors.bgPrimary,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _buildGhostBubbleButton(),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          // Zephyr logo / brand mark.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: zephyrPrimaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Zephyr',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ZephyrColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 24),
          tooltip: 'Settings',
          onPressed: () {
            // Navigate to settings screen.
            _tabController.animateTo(2);
          },
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              UIConstants.spacingMd, 0, UIConstants.spacingMd, 0),
          child: SearchBarWidget(
            onSearch: (query) {
              // TODO: navigate to search results.
              debugPrint('Search: $query');
            },
            onVoiceInput: () {
              // TODO: trigger voice input.
              debugPrint('Voice input triggered');
            },
          ),
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────

  Widget _buildBody() {
    return Consumer<HomeViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          return const _LoadingState();
        }

        return SmartRefresher(
          enablePullDown: true,
          controller: _refreshController,
          onRefresh: vm.refresh,
          header: const WaterDropHeader(
            waterDropColor: ZephyrColors.accentPurple,
            backgroundColor: ZephyrColors.bgPrimary,
          ),
          child: CustomScrollView(
            slivers: [
              // ── Quick Actions ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    UIConstants.spacingMd,
                    UIConstants.spacingSm,
                    UIConstants.spacingMd,
                    UIConstants.spacingMd,
                  ),
                  child: _buildQuickActionsSection(vm),
                ),
              ),

              // ── Stats bar ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UIConstants.spacingMd,
                  ),
                  child: _buildStatsBar(vm.stats),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 12),
              ),

              // ── Recent Conversations header ────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UIConstants.spacingMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Conversations',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          color: ZephyrColors.textPrimary,
                        ),
                      ),
                      if (vm.recentConversations.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            // TODO: navigate to full history.
                          },
                          child: const Text('See All'),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Conversations list ─────────────────────────────────
              if (vm.recentConversations.isEmpty)
                _buildEmptyConversationsSliver()
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final conv = vm.recentConversations[index];
                      return Dismissible(
                        key: Key(conv.id),
                        direction: DismissDirection.endToStart,
                        background: _buildDismissBackground(),
                        confirmDismiss: (direction) async {
                          return await _confirmDelete(
                              context, conv);
                        },
                        onDismissed: (direction) async {
                          await vm.deleteConversation(conv.id);
                        },
                        child: ConversationTile(
                          conversation: conv,
                          onTap: () {
                            // TODO: navigate to chat detail.
                            debugPrint(
                                'Open conversation: ${conv.id}');
                          },
                        ),
                      );
                    },
                    childCount: vm.recentConversations.length,
                  ),
                ),

              // Bottom padding for FAB clearance.
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Quick Actions Section ──────────────────────────────────────────

  Widget _buildQuickActionsSection(HomeViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: ZephyrColors.textPrimary),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: vm.quickActions.length,
          itemBuilder: (context, index) {
            final action = vm.quickActions[index];
            return QuickActionCard(
              icon: action.icon,
              title: action.title,
              subtitle: action.subtitle,
              onTap: () => _handleQuickAction(action.title),
            ).animate(
              delay: (index * 80).ms,
              effects: const [
                FadeEffect(duration: Duration(milliseconds: 300)),
                MoveEffect(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _handleQuickAction(String action) {
    switch (action) {
      case 'New Chat':
        debugPrint('New chat requested');
        break;
      case 'Import Document':
        debugPrint('Import document requested');
        break;
      case 'Ask Screen':
        debugPrint('Ask screen requested');
        break;
      case 'Summarize':
        debugPrint('Summarize requested');
        break;
    }
  }

  // ── Stats Bar ──────────────────────────────────────────────────────

  Widget _buildStatsBar(HomeStats stats) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.spacingMd,
        vertical: UIConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: ZephyrColors.bgSecondary,
        borderRadius: BorderRadius.circular(UIConstants.radiusMd),
        border: Border.all(color: ZephyrColors.divider, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: '${stats.documentsIndexed}',
            label: 'Documents',
            icon: Icons.description_outlined,
          ),
          Container(
            width: 1,
            height: 24,
            color: ZephyrColors.divider,
          ),
          _StatItem(
            value: '${stats.chunksStored}',
            label: 'Chunks',
            icon: Icons.layers_outlined,
          ),
          Container(
            width: 1,
            height: 24,
            color: ZephyrColors.divider,
          ),
          _StatItem(
            value: '${stats.queriesAnswered}',
            label: 'Queries',
            icon: Icons.question_answer_outlined,
          ),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────

  SliverToBoxAdapter _buildEmptyConversationsSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UIConstants.spacingLg,
          vertical: UIConstants.spacingXl * 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: ZephyrColors.bgTertiary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 32,
                color: ZephyrColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ZephyrColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start a new chat to begin exploring',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ZephyrColors.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dismiss background ─────────────────────────────────────────────

  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: ZephyrColors.error.withOpacity(0.15),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: ZephyrColors.error,
        size: 24,
      ),
    );
  }

  // ── Delete confirmation ────────────────────────────────────────────

  Future<bool> _confirmDelete(BuildContext context, ConversationModel conv) {
    return showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Conversation'),
            content: Text(
              'Are you sure you want to delete "${conv.title}"? This action cannot be undone.',
            ),
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
  }

  // ── Bottom Navigation ──────────────────────────────────────────────

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      onDestinationSelected: (index) {
        _tabController.animateTo(index);
      },
      selectedIndex: 0,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.description_outlined),
          selectedIcon: Icon(Icons.description_rounded),
          label: 'Documents',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Settings',
        ),
      ],
    );
  }

  // ── Ghost Bubble FAB ───────────────────────────────────────────────

  Widget _buildGhostBubbleButton() {
    return FloatingActionButton(
      onPressed: () {
        GhostBubbleService().toggle();
      },
      tooltip: 'Ghost Bubble',
      elevation: 6,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: zephyrPrimaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.bolt_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

// ── Loading state ─────────────────────────────────────────────────────

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
            'Loading Zephyr…',
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

// ── Stat item widget ──────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: ZephyrColors.accentPurpleLight),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: ZephyrColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ZephyrColors.textMuted,
              ),
        ),
      ],
    );
  }
}