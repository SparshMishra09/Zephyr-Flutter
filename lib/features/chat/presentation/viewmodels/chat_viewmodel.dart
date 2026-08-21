/// ViewModel for the Chat screen.
///
/// Manages the active conversation, message list, streaming state, and
/// integrates with the RAG pipeline to produce context-aware responses.
/// Uses [AppDatabase] (Hive) for persistence and [RagPipeline] for
/// retrieval-augmented generation.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/models/conversation_model.dart';
import '../../../../core/models/message_model.dart';
import '../../../../core/models/vector_search_result.dart';
import '../../../../core/utils/logger.dart';
import '../../../../rag/pipeline/rag_pipeline.dart';

/// Holds a streaming response in-flight so the UI can display incremental
/// chunks and the final source citations.
class _StreamingState {
  final String messageId;
  final String conversationId;
  String accumulatedText;
  final List<VectorSearchResult> sources;
  StreamSubscription<RagResponse>? subscription;

  _StreamingState({
    required this.messageId,
    required this.conversationId,
    this.accumulatedText = '',
    this.sources = const [],
  });
}

/// Reactive view model for the Zephyr chat screen.
///
/// Listens to Hive box changes so the message list stays in sync with
/// the underlying store.  Coordinates with [RagPipeline] for RAG-based
/// answers and exposes a streaming API so the UI can render tokens as
/// they arrive.
class ChatViewModel extends ChangeNotifier {
  final AppDatabase _db;
  final RagPipeline? _ragPipeline;
  final _uuid = const Uuid();

  ChatViewModel(this._db, {RagPipeline? ragPipeline})
      : _ragPipeline = ragPipeline;

  // ── State ──────────────────────────────────────────────────────────

  ConversationModel? _currentConversation;
  ConversationModel? get currentConversation => _currentConversation;

  List<MessageModel> _messages = [];
  List<MessageModel> get messages => _messages;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _currentQuery;
  String? get currentQuery => _currentQuery;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  _StreamingState? _streamingState;

  // ── Lifecycle ──────────────────────────────────────────────────────

  /// Initialises the view model for a specific conversation.
  ///
  /// Loads the conversation metadata and its messages from Hive, then
  /// subscribes to box listeners for live updates.
  Future<void> init(String conversationId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadConversation(conversationId);
      await _loadMessages();

      // Subscribe to Hive changes so the message list updates reactively.
      _db.messagesBox.listenable().addListener(_onMessagesBoxChanged);
    } catch (e, st) {
      appLogger.severe('Failed to initialise chat', e, st);
      _errorMessage = 'Failed to load conversation. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Called when the underlying messages Hive box changes.
  void _onMessagesBoxChanged() {
    if (_currentConversation != null) {
      _loadMessages();
    }
  }

  @override
  void dispose() {
    // Cancel any in-flight streaming.
    _streamingState?.subscription?.cancel();
    _streamingState = null;
    super.dispose();
  }

  // ── Conversation management ────────────────────────────────────────

  /// Loads a conversation by ID from the database.
  Future<void> _loadConversation(String conversationId) async {
    final raw = _db.conversationsBox.get(conversationId);
    if (raw == null) {
      _currentConversation = null;
      return;
    }

    final map = raw as Map;
    _currentConversation =
        ConversationModel.fromMap(Map<String, dynamic>.from(map));
  }

  /// Public wrapper that also resets state before loading.
  Future<void> loadConversation(String conversationId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadConversation(conversationId);
      await _loadMessages();
    } catch (e) {
      appLogger.severe('Failed to load conversation: $conversationId', e);
      _errorMessage = 'Conversation not found.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads all messages for the current conversation, sorted by timestamp.
  Future<void> _loadMessages() async {
    if (_currentConversation == null) {
      _messages = [];
      notifyListeners();
      return;
    }

    final convId = _currentConversation!.id;
    final rawMessages = <MessageModel>[];

    for (final entry in _db.messagesBox.values) {
      final map = entry as Map;
      final msgMap = Map<String, dynamic>.from(map);
      if ((msgMap['conversationId'] as String?) == convId) {
        rawMessages.add(MessageModel.fromMap(msgMap));
      }
    }

    // Sort by timestamp ascending so the earliest message is first.
    rawMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Ensure no message is marked as streaming on load (they're persisted).
    _messages = rawMessages
        .map((m) => m.copyWith(isStreaming: false))
        .toList();

    notifyListeners();
  }

  /// Creates a brand-new conversation and switches to it.
  Future<String> createNewConversation() async {
    final id = _uuid.v4();
    final conversation = ConversationModel.initial(id: id);

    await _db.conversationsBox.put(id, conversation.toMap());

    _currentConversation = conversation;
    _messages = [];
    _errorMessage = null;
    notifyListeners();

    return id;
  }

  /// Updates the conversation title (e.g. auto-generated from first message).
  Future<void> updateConversationTitle(String newTitle) async {
    if (_currentConversation == null) return;

    final updated = _currentConversation!.copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );

    await _db.conversationsBox.put(updated.id, updated.toMap());
    _currentConversation = updated;
    notifyListeners();
  }

  // ── Messaging ──────────────────────────────────────────────────────

  /// Sends a user message and triggers a RAG-based assistant response.
  ///
  /// If [_ragPipeline] is null, falls back to a simple echo placeholder.
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || _currentConversation == null || isStreaming) {
      return;
    }

    final convId = _currentConversation!.id;
    _errorMessage = null;
    _currentQuery = content.trim();
    notifyListeners();

    // ── 1. Persist the user message ──────────────────────────────────
    final userMsg = MessageModel.userMessage(
      id: _uuid.v4(),
      conversationId: convId,
      content: content.trim(),
    );

    await _db.messagesBox.put(userMsg.id, userMsg.toMap());
    _messages.add(userMsg);

    // Auto-title the conversation on the first user message.
    if (_messages.length == 1) {
      final title = content.trim().length > 40
          ? '${content.trim().substring(0, 40)}…'
          : content.trim();
      await updateConversationTitle(title);
    }

    notifyListeners();

    // ── 2. Start streaming the assistant response ────────────────────
    await streamResponse(content.trim());
  }

  /// Streams a RAG-based assistant response, appending chunks to the last
  /// message in real time.
  ///
  /// The UI observes [_isStreaming] and the growing [messages] list to
  /// render the typing animation and incremental text.
  Future<void> streamResponse(String query) async {
    if (_currentConversation == null) return;

    final convId = _currentConversation!.id;
    final assistantMsgId = _uuid.v4();

    _isStreaming = true;
    _streamingState = _StreamingState(
      messageId: assistantMsgId,
      conversationId: convId,
    );

    // Add a placeholder assistant message so the UI can render it.
    final placeholder = MessageModel.assistantMessage(
      id: assistantMsgId,
      conversationId: convId,
      content: '',
      isStreaming: true,
    );

    _messages.add(placeholder);
    notifyListeners();

    try {
      if (_ragPipeline != null) {
        // ── RAG streaming path ───────────────────────────────────────
        final stream = _ragPipeline!.queryStreaming(query);

        _streamingState!.subscription = stream.listen(
          (ragResponse) {
            _streamingState!.accumulatedText = ragResponse.text;
            _streamingState!.sources = ragResponse.sources;

            // Update the last message in-place with the accumulated text.
            if (_messages.isNotEmpty) {
              final last = _messages.last;
              _messages[_messages.length - 1] = last.copyWith(
                content: ragResponse.text,
              );
              notifyListeners();
            }
          },
          onError: (Object error) {
            appLogger.severe('RAG stream error', error);
            _handleStreamingError('Failed to generate response. Please try again.');
          },
          onDone: () {
            _finalizeStreaming();
          },
        );
      } else {
        // ── Fallback: no RAG pipeline configured ─────────────────────
        await Future.delayed(const Duration(milliseconds: 600));
        _streamingState!.accumulatedText =
            'RAG pipeline not configured. This is a placeholder response for: "$query"';
        _finalizeStreaming();
      }
    } catch (e, st) {
      appLogger.severe('streamResponse failed', e, st);
      _handleStreamingError('An unexpected error occurred. Please try again.');
    }
  }

  /// Finalises the streaming response: persists the message, clears
  /// streaming state, and updates the conversation.
  void _finalizeStreaming() {
    final state = _streamingState;
    if (state == null) return;

    state.subscription?.cancel();

    final finalMessage = MessageModel.assistantMessage(
      id: state.messageId,
      conversationId: state.conversationId,
      content: state.accumulatedText,
      sources: state.sources.map((s) => s.chunkId).toList(),
      isStreaming: false,
    );

    // Persist to Hive.
    _db.messagesBox.put(finalMessage.id, finalMessage.toMap());

    // Replace the placeholder in the in-memory list.
    final idx = _messages.indexWhere((m) => m.id == state.messageId);
    if (idx != -1) {
      _messages[idx] = finalMessage;
    }

    // Update conversation metadata.
    if (_currentConversation != null) {
      final updated = _currentConversation!.copyWith(
        updatedAt: DateTime.now(),
        messageCount: _messages.length,
      );
      _db.conversationsBox.put(updated.id, updated.toMap());
      _currentConversation = updated;
    }

    _streamingState = null;
    _isStreaming = false;
    _currentQuery = null;
    notifyListeners();
  }

  /// Handles an error during streaming: appends a user-friendly error
  /// message and clears streaming state.
  void _handleStreamingError(String userMessage) {
    final state = _streamingState;
    if (state == null) {
      _errorMessage = userMessage;
      _isStreaming = false;
      _currentQuery = null;
      notifyListeners();
      return;
    }

    state.subscription?.cancel();

    // Append error hint to the accumulated text.
    final errorContent = '${state.accumulatedText}\n\n⚠️ $userMessage';

    final errorMessage = MessageModel.assistantMessage(
      id: state.messageId,
      conversationId: state.conversationId,
      content: errorContent,
      isStreaming: false,
    );

    _db.messagesBox.put(errorMessage.id, errorMessage.toMap());

    final idx = _messages.indexWhere((m) => m.id == state.messageId);
    if (idx != -1) {
      _messages[idx] = errorMessage;
    }

    _errorMessage = userMessage;
    _streamingState = null;
    _isStreaming = false;
    _currentQuery = null;
    notifyListeners();
  }

  /// Deletes a single message by ID from both Hive and the in-memory list.
  Future<void> deleteMessage(String messageId) async {
    await _db.messagesBox.delete(messageId);
    _messages.removeWhere((m) => m.id == messageId);

    // Update message count on the conversation.
    if (_currentConversation != null) {
      final updated = _currentConversation!.copyWith(
        messageCount: _messages.length,
        updatedAt: DateTime.now(),
      );
      await _db.conversationsBox.put(updated.id, updated.toMap());
      _currentConversation = updated;
    }

    notifyListeners();
  }

  /// Cancels an in-flight streaming response.
  void cancelStreaming() {
    _streamingState?.subscription?.cancel();
    _streamingState = null;
    _isStreaming = false;
    _currentQuery = null;

    // Remove the partial assistant message if it exists.
    if (_messages.isNotEmpty && _messages.last.isStreaming) {
      _messages.removeLast();
    }

    notifyListeners();
  }

  /// Clears the error banner.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Checks if there is a streaming message at the end of the list.
  bool get hasStreamingMessage =>
      _messages.isNotEmpty && _messages.last.isStreaming;

  /// Gets the source document titles for a message's citations.
  ///
  /// Looks up document titles from the documents box using the chunk IDs
  /// stored in [message.sources].
  Future<List<String>> getSourceTitles(MessageModel message) async {
    final titles = <String>{};

    for (final chunkId in message.sources) {
      final chunkRaw = _db.chunksBox.get(chunkId);
      if (chunkRaw != null) {
        final chunkMap = chunkRaw as Map;
        final docId = chunkMap['documentId'] as String?;
        if (docId != null) {
          final docRaw = _db.documentsBox.get(docId);
          if (docRaw != null) {
            final docMap = docRaw as Map;
            final title = docMap['title'] as String?;
            if (title != null) {
              titles.add(title);
            }
          }
        }
      }
    }

    return titles.toList();
  }
}