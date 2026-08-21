/// ViewModel for the Home screen.
///
/// Manages recent conversations, quick-action stats, and pull-to-refresh
/// state. Uses [AppDatabase] to read conversations from the Hive store
/// and exposes them as a sorted, reactive list.
library;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/models/conversation_model.dart';

// ── Stats model ────────────────────────────────────────────────────────

/// Lightweight snapshot of the knowledge-base statistics displayed on
/// the home screen.
class HomeStats {
  final int documentsIndexed;
  final int chunksStored;
  final int queriesAnswered;

  const HomeStats({
    this.documentsIndexed = 0,
    this.chunksStored = 0,
    this.queriesAnswered = 0,
  });

  /// Human-readable summary string (e.g. "12 docs · 847 chunks").
  String get summary {
    final parts = <String>[];
    if (documentsIndexed > 0) parts.add('$documentsIndexed docs');
    if (chunksStored > 0) parts.add('$chunksStored chunks');
    if (queriesAnswered > 0) parts.add('$queriesAnswered queries');
    return parts.join(' · ');
  }

  HomeStats copyWith({
    int? documentsIndexed,
    int? chunksStored,
    int? queriesAnswered,
  }) {
    return HomeStats(
      documentsIndexed: documentsIndexed ?? this.documentsIndexed,
      chunksStored: chunksStored ?? this.chunksStored,
      queriesAnswered: queriesAnswered ?? this.queriesAnswered,
    );
  }
}

// ── Quick action model ─────────────────────────────────────────────────

/// Represents a single quick-action card on the home screen.
class QuickAction {
  final IconData icon;
  final String title;
  final String subtitle;

  const QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

// ── ViewModel ──────────────────────────────────────────────────────────

/// Reactive view model for the Zephyr home screen.
///
/// Listens to Hive box changes so the conversation list stays in sync
/// without explicit refresh calls.
class HomeViewModel extends ChangeNotifier {
  final AppDatabase _db;

  HomeViewModel(this._db);

  // ── State ──────────────────────────────────────────────────────────

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  List<ConversationModel> _recentConversations = [];
  List<ConversationModel> get recentConversations => _recentConversations;

  HomeStats _stats = const HomeStats();
  HomeStats get stats => _stats;

  // Pre-defined quick actions shown on the home screen.
  List<QuickAction> get quickActions => _quickActions;

  static const List<QuickAction> _quickActions = [
    QuickAction(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'New Chat',
      subtitle: 'Start a conversation',
    ),
    QuickAction(
      icon: Icons.upload_file_rounded,
      title: 'Import Document',
      subtitle: 'Add to knowledge base',
    ),
    QuickAction(
      icon: Icons.screenshot_monitor_rounded,
      title: 'Ask Screen',
      subtitle: 'Query what you see',
    ),
    QuickAction(
      icon: Icons.summarize_rounded,
      title: 'Summarize',
      subtitle: 'Condense a document',
    ),
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────

  /// Initialises the view model: loads conversations and stats, then
  /// subscribes to Hive box listeners for live updates.
  Future<void> init() async {
    await Future.wait([
      _loadConversations(),
      loadStats(),
    ]);

    // Subscribe to Hive changes so the list updates reactively.
    _db.conversationsBox.listenable().addListener(_onBoxChanged);

    _isLoading = false;
    notifyListeners();
  }

  /// Called when the underlying Hive box changes (insert / delete / clear).
  void _onBoxChanged() {
    _loadConversations();
    loadStats();
  }

  // ── Conversations ──────────────────────────────────────────────────

  /// Loads and sorts conversations from the database, newest first.
  Future<void> _loadConversations() async {
    final conversations = getRecentConversations();
    if (!listEquals(_recentConversations, conversations)) {
      _recentConversations = conversations;
      notifyListeners();
    }
  }

  /// Returns all conversations sorted by [updatedAt] descending.
  ///
  /// Pinned conversations appear at the top regardless of date.
  List<ConversationModel> getRecentConversations() {
    final raw = _db.conversationsBox.values.map((raw) {
      final map = raw as Map;
      return ConversationModel.fromMap(Map<String, dynamic>.from(map));
    }).toList();

    // Sort: pinned first, then by updatedAt descending.
    raw.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return raw;
  }

  /// Deletes a conversation by its ID.
  Future<void> deleteConversation(String id) async {
    await _db.conversationsBox.delete(id);
    // Also delete associated messages.
    final keysToDelete = _db.messagesBox.keys
        .where((key) =>
            key is String &&
            _db.messagesBox.get(key) is Map &&
            (Map.from(_db.messagesBox.get(key))['conversationId'] as String?) ==
                id)
        .toList();
    for (final key in keysToDelete) {
      await _db.messagesBox.delete(key);
    }
    await _loadConversations();
    await loadStats();
  }

  // ── Stats ──────────────────────────────────────────────────────────

  /// Reads aggregate statistics from the Hive boxes.
  Future<void> loadStats() async {
    final docs = _db.documentsBox.values.length;
    final chunks = _db.chunksBox.values.length;

    // Count unique conversation IDs that have assistant messages.
    final answeredConversations = <String>{};
    for (final entry in _db.messagesBox.values) {
      final map = entry as Map;
      final role = map['role'] as String?;
      if (role == 'assistant') {
        final convId = map['conversationId'] as String?;
        if (convId != null) {
          answeredConversations.add(convId);
        }
      }
    }

    _stats = HomeStats(
      documentsIndexed: docs,
      chunksStored: chunks,
      queriesAnswered: answeredConversations.length,
    );

    notifyListeners();
  }

  // ── Pull-to-refresh ────────────────────────────────────────────────

  /// Refresh handler for the RefreshIndicator.
  Future<void> refresh() async {
    _isRefreshing = true;
    notifyListeners();

    await Future.wait([
      _loadConversations(),
      loadStats(),
    ]);

    _isRefreshing = false;
    notifyListeners();
  }
}