/// Data model representing a single hit from a vector similarity search.
///
/// After a query embedding is compared against the stored chunks, each
/// matching chunk is wrapped in this class together with its relevance
/// [score] and the original [documentId] it belongs to.
library;

import 'package:equatable/equatable.dart';

/// One result row returned by a vector search operation.
class VectorSearchResult extends Equatable {
  /// ID of the matching chunk.
  final String chunkId;

  /// ID of the parent document the chunk belongs to.
  final String documentId;

  /// Similarity score (higher is more relevant).
  ///
  /// Typically a cosine similarity value in the range `[0, 1]`.
  final double score;

  /// The raw text content of the matching chunk.
  final String content;

  /// Arbitrary metadata attached to the chunk at indexing time.
  final Map<String, dynamic> metadata;

  const VectorSearchResult({
    required this.chunkId,
    required this.documentId,
    required this.score,
    required this.content,
    this.metadata = const {},
  });

  // ── Converters ──────────────────────────────────────────────────────

  /// Serialises to a [Map] for transport or logging.
  Map<String, dynamic> toMap() => {
        'chunkId': chunkId,
        'documentId': documentId,
        'score': score,
        'content': content,
        'metadata': metadata,
      };

  /// Reconstructs from a [Map].
  factory VectorSearchResult.fromMap(Map<String, dynamic> map) {
    return VectorSearchResult(
      chunkId: map['chunkId'] as String,
      documentId: map['documentId'] as String,
      score: (map['score'] as num).toDouble(),
      content: map['content'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  /// Returns a copy with the specified fields replaced.
  VectorSearchResult copyWith({
    String? chunkId,
    String? documentId,
    double? score,
    String? content,
    Map<String, dynamic>? metadata,
  }) {
    return VectorSearchResult(
      chunkId: chunkId ?? this.chunkId,
      documentId: documentId ?? this.documentId,
      score: score ?? this.score,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [chunkId, documentId, score, content, metadata];

  @override
  String toString() =>
      'VectorSearchResult(chunkId: $chunkId, score: ${score.toStringAsFixed(4)})';
}