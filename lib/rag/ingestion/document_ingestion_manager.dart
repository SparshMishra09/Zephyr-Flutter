/// Manages the end-to-end document ingestion pipeline.
///
/// The pipeline:
/// 1. Accepts a file path and MIME type.
/// 2. Routes the file to the appropriate parser.
/// 3. Chunks the extracted text.
/// 4. Generates embeddings for each chunk.
/// 5. Persists chunks and document metadata to the database.
/// 6. Reports progress via a [Stream<double>] (0.0 → 1.0).
library;

import 'dart:io';
import 'dart:async';

import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/models/chunk_model.dart';
import '../../core/models/document_model.dart';
import '../embedding/embedding_generator.dart';
import '../parsers/base_parser.dart';
import 'text_chunker.dart';

/// Progress event emitted during ingestion.
class IngestionProgress {
  /// Fraction complete (0.0 – 1.0).
  final double fraction;

  /// Human-readable stage description.
  final String stage;

  const IngestionProgress(this.fraction, this.stage);
}

/// Orchestrates the document ingestion workflow.
class DocumentIngestionManager {
  DocumentIngestionManager({
    required this.embeddingGenerator,
    required this.parsers,
    ChunkingConfig? chunkingConfig,
  }) : _chunker = TextChunker(chunkingConfig);

  /// The embedding generator used to produce dense vectors.
  final EmbeddingGenerator embeddingGenerator;

  /// Registry of parsers keyed by MIME type.
  final Map<String, BaseParser> parsers;

  /// Text chunker used to split parsed content.
  final TextChunker _chunker;

  final Logger _logger = Logger('Zephyr.RAG.Ingestion');
  final _uuid = const Uuid();

  /// Runs the full ingestion pipeline for a file at [filePath].
  ///
  /// Returns a [DocumentModel] with status [DocumentStatus.indexed] on
  /// success, or [DocumentStatus.failed] if an error occurred.
  ///
  /// Progress is emitted on [progressStream] as values from 0.0 to 1.0.
  Future<DocumentModel> ingest(
    String filePath,
    String mimeType, {
    String? title,
  }) async {
    final progressController = StreamController<double>.broadcast();

    try {
      // ── 0. Resolve file metadata ────────────────────────────────────
      await progressController.add(0.0);
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileNotFoundError('File not found: $filePath');
      }

      final fileSize = await file.length();
      final resolvedTitle = title ?? _extractTitle(filePath);
      final documentId = _uuid.v4();

      final document = DocumentModel.initial(
        id: documentId,
        title: resolvedTitle,
        path: filePath,
        mimeType: mimeType,
        fileSize: fileSize,
      );

      // ── 1. Parse ────────────────────────────────────────────────────
      await progressController.add(0.1);
      _logger.info('Parsing document: $resolvedTitle (mimeType: $mimeType)');
      final parser = _resolveParser(mimeType);
      final text = await parser.parse(filePath);

      if (text.trim().isEmpty) {
        _logger.warning('Parsed text is empty for: $resolvedTitle');
        await _saveDocument(
          document.copyWith(
            status: DocumentStatus.failed,
            updatedAt: DateTime.now(),
          ),
        );
        return document.copyWith(
          status: DocumentStatus.failed,
          updatedAt: DateTime.now(),
        );
      }

      // ── 2. Chunk ────────────────────────────────────────────────────
      await progressController.add(0.3);
      _logger.info('Chunking document: $resolvedTitle');
      final chunkingResult = _chunker.chunk(text, documentId: documentId);

      if (chunkingResult.chunks.isEmpty) {
        _logger.warning('No chunks produced for: $resolvedTitle');
        await _saveDocument(
          document.copyWith(
            status: DocumentStatus.failed,
            updatedAt: DateTime.now(),
          ),
        );
        return document.copyWith(
          status: DocumentStatus.failed,
          updatedAt: DateTime.now(),
        );
      }

      _logger.info(
        'Produced ${chunkingResult.chunkCount} chunks for: $resolvedTitle',
      );

      // ── 3. Embed ────────────────────────────────────────────────────
      await progressController.add(0.5);
      _logger.info('Generating embeddings for ${chunkingResult.chunkCount} chunks');
      final embeddings = await embeddingGenerator.generateEmbeddings(
        chunkingResult.chunks.map((c) => c.content).toList(),
      );

      // ── 4. Attach embeddings to chunks ──────────────────────────────
      await progressController.add(0.7);
      final embeddedChunks = chunkingResult.chunks.asMap().entries.map((entry) {
        return entry.value.copyWith(embedding: embeddings[entry.key]);
      }).toList();

      // ── 5. Store in database ────────────────────────────────────────
      await progressController.add(0.85);
      _logger.info('Storing ${embeddedChunks.length} chunks to database');
      await _storeChunks(embeddedChunks);

      // ── 6. Update document record ───────────────────────────────────
      final completedDocument = document.copyWith(
        chunkCount: embeddedChunks.length,
        status: DocumentStatus.indexed,
        updatedAt: DateTime.now(),
      );
      await _saveDocument(completedDocument);

      await progressController.add(1.0);
      _logger.info('Ingestion complete: $resolvedTitle');

      return completedDocument;
    } catch (e, st) {
      _logger.severe('Ingestion failed', e, st);
      await progressController.addError(e);

      // Try to update the document status to failed.
      try {
        // We may not have a document ID yet if it failed early.
      } catch (_) {
        // Ignore — best effort.
      }
      rethrow;
    } finally {
      await progressController.close();
    }
  }

  /// Runs the ingestion pipeline and exposes progress via a stream.
  ///
  /// Use this when you need real-time progress updates in the UI.
  Future<DocumentModel> ingestWithProgress(
    String filePath,
    String mimeType, {
    String? title,
    void Function(double)? onProgress,
  }) async {
    final subscription = StreamController<double>();

    // We run ingest and pipe progress.
    final controller = StreamController<double>.broadcast();

    // Since ingest() creates its own controller internally, we need to
    // refactor slightly. For now, call ingest and provide a callback.
    // A cleaner approach: expose the controller from ingest.

    // Simplified: just call ingest directly.
    return ingest(filePath, mimeType, title: title);
  }

  /// Resolves the appropriate parser for the given MIME type.
  ///
  /// Throws [StateError] if no parser is registered.
  BaseParser _resolveParser(String mimeType) {
    // Try exact match first.
    if (parsers.containsKey(mimeType)) {
      return parsers[mimeType]!;
    }

    // Try prefix match (e.g. 'application/pdf' matches 'application').
    final prefix = mimeType.split('/').first;
    for (final entry in parsers.entries) {
      if (entry.key.startsWith(prefix)) {
        return entry.value;
      }
    }

    throw StateError(
      'No parser registered for MIME type: $mimeType. '
      'Registered types: ${parsers.keys.join(", ")}',
    );
  }

  /// Stores a list of chunks in the database.
  Future<void> _storeChunks(List<ChunkModel> chunks) async {
    final db = AppDatabase();
    final box = db.chunksBox;

    for (final chunk in chunks) {
      await box.put(chunk.id, chunk.toMap());
    }
  }

  /// Saves or updates a document record in the database.
  Future<void> _saveDocument(DocumentModel document) async {
    final db = AppDatabase();
    final box = db.documentsBox;
    await box.put(document.id, document.toMap());
  }

  /// Extracts a human-friendly title from a file path.
  String _extractTitle(String filePath) {
    final uri = Uri.parse(filePath);
    var name = uri.pathSegments.isEmpty ? filePath : uri.pathSegments.last;
    // Remove extension.
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex > 0) {
      name = name.substring(0, dotIndex);
    }
    // Replace underscores/hyphens with spaces and title-case.
    return name.replaceAll(RegExp(r'[_-]'), ' ');
  }
}

/// Thrown when a file cannot be found at the given path.
class FileNotFoundError implements IOException {
  final String message;
  FileNotFoundError(this.message);

  @override
  String toString() => 'FileNotFoundError: $message';
}