/// Data model representing a document that has been (or will be) indexed.
///
/// Each document is split into [TextChunk] objects whose embeddings are
/// stored in the vector store. The [status] field tracks the indexing
/// lifecycle.
library;

import 'package:equatable/equatable.dart';

/// Possible states of a document in the indexing pipeline.
enum DocumentStatus {
  /// The document is currently being chunked and embedded.
  indexing,

  /// Indexing completed successfully; chunks are available for search.
  indexed,

  /// Indexing failed — check logs for the underlying error.
  failed,
}

/// A file that has been ingested into Zephyr's knowledge base.
class DocumentModel extends Equatable {
  /// Unique identifier (e.g. a UUID).
  final String id;

  /// Human-readable file name or title.
  final String title;

  /// Absolute or relative file system path.
  final String path;

  /// MIME type of the original file (e.g. `application/pdf`).
  final String mimeType;

  /// Size of the original file in bytes.
  final int fileSize;

  /// Timestamp when the document was first added.
  final DateTime createdAt;

  /// Timestamp of the last modification or re-index.
  final DateTime updatedAt;

  /// Number of text chunks this document was split into.
  final int chunkCount;

  /// Current indexing state.
  final DocumentStatus status;

  const DocumentModel({
    required this.id,
    required this.title,
    required this.path,
    required this.mimeType,
    required this.fileSize,
    required this.createdAt,
    required this.updatedAt,
    this.chunkCount = 0,
    this.status = DocumentStatus.indexing,
  });

  // ── Factories ───────────────────────────────────────────────────────

  /// Creates a fresh document record ready for indexing.
  factory DocumentModel.initial({
    required String id,
    required String title,
    required String path,
    required String mimeType,
    required int fileSize,
  }) {
    final now = DateTime.now();
    return DocumentModel(
      id: id,
      title: title,
      path: path,
      mimeType: mimeType,
      fileSize: fileSize,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── Converters ──────────────────────────────────────────────────────

  /// Serialises the model to a [Map] suitable for Hive storage.
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'path': path,
        'mimeType': mimeType,
        'fileSize': fileSize,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'chunkCount': chunkCount,
        'status': status.name,
      };

  /// Reconstructs a [DocumentModel] from a Hive [Map].
  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'] as String,
      title: map['title'] as String,
      path: map['path'] as String,
      mimeType: map['mimeType'] as String,
      fileSize: map['fileSize'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      chunkCount: map['chunkCount'] as int? ?? 0,
      status: DocumentStatus.values.byName(map['status'] as String? ?? 'indexing'),
    );
  }

  // ── Builders ────────────────────────────────────────────────────────

  /// Returns a copy with the specified fields replaced.
  DocumentModel copyWith({
    String? id,
    String? title,
    String? path,
    String? mimeType,
    int? fileSize,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? chunkCount,
    DocumentStatus? status,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      chunkCount: chunkCount ?? this.chunkCount,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        path,
        mimeType,
        fileSize,
        createdAt,
        updatedAt,
        chunkCount,
        status,
      ];
}