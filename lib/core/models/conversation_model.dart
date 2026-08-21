/// Data model representing a conversation thread between the user and the AI.
///
/// A conversation groups multiple [ChatMessage] records and can be pinned
/// to the top of the conversation list.
library;

import 'package:equatable/equatable.dart';

/// A single chat session.
class ConversationModel extends Equatable {
  /// Unique identifier (e.g. a UUID).
  final String id;

  /// Short title displayed in the conversation list.
  final String title;

  /// Timestamp when the conversation was created.
  final DateTime createdAt;

  /// Timestamp of the last message sent or received.
  final DateTime updatedAt;

  /// Number of messages in this conversation.
  final int messageCount;

  /// Whether the conversation is pinned to the top of the list.
  final bool isPinned;

  const ConversationModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
    this.isPinned = false,
  });

  // ── Factories ───────────────────────────────────────────────────────

  /// Creates a brand-new, empty conversation.
  factory ConversationModel.initial({required String id}) {
    final now = DateTime.now();
    return ConversationModel(
      id: id,
      title: 'New Chat',
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── Converters ──────────────────────────────────────────────────────

  /// Serialises the model to a [Map] suitable for Hive storage.
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messageCount': messageCount,
        'isPinned': isPinned,
      };

  /// Reconstructs a [ConversationModel] from a Hive [Map].
  factory ConversationModel.fromMap(Map<String, dynamic> map) {
    return ConversationModel(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      messageCount: map['messageCount'] as int? ?? 0,
      isPinned: map['isPinned'] as bool? ?? false,
    );
  }

  // ── Builders ────────────────────────────────────────────────────────

  /// Returns a copy with the specified fields replaced.
  ConversationModel copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? messageCount,
    bool? isPinned,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageCount: messageCount ?? this.messageCount,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        createdAt,
        updatedAt,
        messageCount,
        isPinned,
      ];
}