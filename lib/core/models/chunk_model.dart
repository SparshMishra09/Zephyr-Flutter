/// Data model representing a chunk of text extracted from a document.
///
/// Each chunk carries its own dense embedding vector so that similarity
/// search can retrieve the most relevant passages at query time.
library;

import 'package:equatable/equatable.dart';

/// A contiguous segment of text belonging to a parent document.
class ChunkModel extends Equatable {
  /// Unique identifier for this chunk.
  final String id;

  /// ID of the parent [DocumentModel].
  final String documentId;

  /// The raw text content of the chunk.
  final String content;

  /// Dense embedding vector produced by the embedding model.
  ///
  /// An empty list indicates the chunk has not yet been embedded.
  final List<double> embedding;

  /// Zero-based character offset where this chunk starts in the original text.
  final int startIndex;

  /// Zero-based character offset where this chunk ends (exclusive).
  final int endIndex;

  /// Arbitrary key-value pairs attached to the chunk
  /// (e.g. page number, section heading).
  final Map<String, dynamic> metadata;

  const ChunkModel({
    required this.id,
    required this.documentId,
    required this.content,
    required this.startIndex,
    required this.endIndex,
    this.embedding = const [],
    this.metadata = const {},
  });

  // ── Factories ───────────────────────────────────────────────────────

  /// Creates a chunk that has not yet been embedded.
  factory ChunkModel.unembedded({
    required String id,
    required String documentId,
    required String content,
    required int startIndex,
    required int endIndex,
    Map<String, dynamic> metadata = const {},
  }) {
    return ChunkModel(
      id: id,
      documentId: documentId,
      content: content,
      startIndex: startIndex,
      endIndex: endIndex,
      metadata: metadata,
    );
  }

  // ── Converters ──────────────────────────────────────────────────────

  /// Serialises the model to a [Map] suitable for Hive storage.
  Map<String, dynamic> toMap() => {
        'id': id,
        'documentId': documentId,
        'content': content,
        'embedding': embedding,
        'startIndex': startIndex,
        'endIndex': endIndex,
        'metadata': metadata,
      };

  /// Reconstructs a [ChunkModel] from a Hive [Map].
  factory ChunkModel.fromMap(Map<String, dynamic> map) {
    return ChunkModel(
      id: map['id'] as String,
      documentId: map['documentId'] as String,
      content: map['content'] as String,
      embedding: (map['embedding'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      startIndex: map['startIndex'] as int? ?? 0,
      endIndex: map['endIndex'] as int? ?? 0,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  // ── Builders ────────────────────────────────────────────────────────

  /// Returns a copy with the specified fields replaced.
  ChunkModel copyWith({
    String? id,
    String? documentId,
    String? content,
    List<double>? embedding,
    int? startIndex,
    int? endIndex,
    Map<String, dynamic>? metadata,
  }) {
    return ChunkModel(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      content: content ?? this.content,
      embedding: embedding ?? this.embedding,
      startIndex: startIndex ?? this.startIndex,
      endIndex: endIndex ?? this.endIndex,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
        id,
        documentId,
        content,
        embedding,
        startIndex,
        endIndex,
        metadata,
      ];
}