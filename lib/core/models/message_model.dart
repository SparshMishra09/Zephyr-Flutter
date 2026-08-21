/// Data model representing a single message within a conversation.
///
/// Messages carry the speaker [role], the text [content], and optionally
/// a list of source document IDs that were used to generate the response.
library;

import 'package:equatable/equatable.dart';

/// The participant who authored the message.
enum MessageRole {
  /// The end-user.
  user,

  /// The AI assistant.
  assistant,

  /// An internal system note (not shown to the user).
  system,
}

/// A single turn in a chat conversation.
class MessageModel extends Equatable {
  /// Unique identifier (e.g. a UUID).
  final String id;

  /// ID of the parent [ConversationModel].
  final String conversationId;

  /// Who authored this message.
  final MessageRole role;

  /// The message text.
  final String content;

  /// Timestamp when the message was created.
  final DateTime timestamp;

  /// IDs of source chunks or documents cited in an assistant reply.
  final List<String> sources;

  /// Whether the message is still being streamed in.
  final bool isStreaming;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.sources = const [],
    this.isStreaming = false,
  });

  // ── Factories ───────────────────────────────────────────────────────

  /// Creates a user message.
  factory MessageModel.userMessage({
    required String id,
    required String conversationId,
    required String content,
  }) {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  /// Creates an assistant message.
  factory MessageModel.assistantMessage({
    required String id,
    required String conversationId,
    required String content,
    List<String> sources = const [],
    bool isStreaming = false,
  }) {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      role: MessageRole.assistant,
      content: content,
      timestamp: DateTime.now(),
      sources: sources,
      isStreaming: isStreaming,
    );
  }

  // ── Converters ──────────────────────────────────────────────────────

  /// Serialises the model to a [Map] suitable for Hive storage.
  Map<String, dynamic> toMap() => {
        'id': id,
        'conversationId': conversationId,
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'sources': sources,
        'isStreaming': isStreaming,
      };

  /// Reconstructs a [MessageModel] from a Hive [Map].
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as String,
      conversationId: map['conversationId'] as String,
      role: MessageRole.values.byName(map['role'] as String? ?? 'user'),
      content: map['content'] as String? ?? '',
      timestamp: DateTime.parse(map['timestamp'] as String),
      sources: List<String>.from(map['sources'] ?? []),
      isStreaming: map['isStreaming'] as bool? ?? false,
    );
  }

  // ── Builders ────────────────────────────────────────────────────────

  /// Returns a copy with the specified fields replaced.
  MessageModel copyWith({
    String? id,
    String? conversationId,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    List<String>? sources,
    bool? isStreaming,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      sources: sources ?? this.sources,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  @override
  List<Object?> get props => [
        id,
        conversationId,
        role,
        content,
        timestamp,
        sources,
        isStreaming,
      ];
}