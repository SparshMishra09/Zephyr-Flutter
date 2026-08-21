/// Text chunking utilities for splitting documents into retrievable segments.
///
/// The chunker breaks long text into smaller, semantically coherent pieces
/// while preserving sentence boundaries and maintaining configurable overlap
/// between consecutive chunks.
library;

import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../../core/models/chunk_model.dart';

/// Configuration for text chunking behaviour.
class ChunkingConfig {
  /// Maximum number of characters per chunk.
  final int chunkSize;

  /// Number of overlapping characters between consecutive chunks.
  final int overlapSize;

  /// Whether to attempt splitting at sentence boundaries.
  final bool preserveSentenceBoundaries;

  const ChunkingConfig({
    this.chunkSize = 500,
    this.overlapSize = 50,
    this.preserveSentenceBoundaries = true,
  });

  /// Validates that the configuration is sensible.
  ///
  /// Throws [ArgumentError] if [overlapSize] >= [chunkSize] or if either
  /// value is non-positive.
  void validate() {
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'Must be positive.');
    }
    if (overlapSize < 0) {
      throw ArgumentError.value(
        overlapSize,
        'overlapSize',
        'Must be non-negative.',
      );
    }
    if (overlapSize >= chunkSize) {
      throw ArgumentError.value(
        overlapSize,
        'overlapSize',
        'Must be less than chunkSize ($chunkSize).',
      );
    }
  }
}

/// Result of a single chunking operation.
class ChunkingResult {
  /// The list of chunks produced.
  final List<ChunkModel> chunks;

  /// Total number of characters in the original text.
  final int totalCharacters;

  /// Number of chunks produced.
  int get chunkCount => chunks.length;

  const ChunkingResult({
    required this.chunks,
    required this.totalCharacters,
  });
}

/// Splits text into overlapping chunks with configurable parameters.
class TextChunker {
  TextChunker([this.config = const ChunkingConfig()]);

  /// Chunking configuration.
  final ChunkingConfig config;

  final _uuid = const Uuid();

  /// Splits [text] into [ChunkModel] instances.
  ///
  /// Each chunk is associated with the given [documentId] and carries
  /// metadata about its position in the source text.
  ///
  /// If [text] is shorter than [ChunkingConfig.chunkSize], a single chunk
  /// is returned containing the entire text.
  ChunkingResult chunk(String text, {required String documentId}) {
    config.validate();

    if (text.trim().isEmpty) {
      return ChunkingResult(chunks: [], totalCharacters: text.length);
    }

    final chunks = <ChunkModel>[];

    if (config.preserveSentenceBoundaries) {
      _chunkWithSentenceBoundaries(text, documentId, chunks);
    } else {
      _chunkWithFixedWindows(text, documentId, chunks);
    }

    return ChunkingResult(
      chunks: chunks,
      totalCharacters: text.length,
    );
  }

  /// Splits text respecting sentence boundaries.
  ///
  /// First identifies sentence break points, then greedily accumulates
  /// sentences until the chunk size limit is reached. Overlap is achieved
  /// by carrying forward the last few sentences from the previous chunk.
  void _chunkWithSentenceBoundaries(
    String text,
    String documentId,
    List<ChunkModel> chunks,
  ) {
    final sentences = _splitIntoSentences(text);

    if (sentences.isEmpty) {
      // Fallback: treat the whole text as one chunk.
      chunks.add(_makeChunk(
        id: _uuid.v4(),
        documentId: documentId,
        content: text,
        startIndex: 0,
        endIndex: text.length,
      ));
      return;
    }

    var currentStart = 0;
    var sentenceIndex = 0;
    var overlapSentences = <String>[];

    while (sentenceIndex < sentences.length) {
      // Start with any overlap sentences from the previous chunk.
      var currentContent = overlapSentences.join(' ');
      var currentStartIdx = currentStart;

      // Accumulate sentences until we approach the chunk size limit.
      while (sentenceIndex < sentences.length) {
        final candidate = currentContent.isEmpty
            ? sentences[sentenceIndex]
            : '$currentContent ${sentences[sentenceIndex]}';

        if (candidate.length > config.chunkSize && currentContent.isNotEmpty) {
          break;
        }

        currentContent = candidate;
        sentenceIndex++;
      }

      if (currentContent.trim().isEmpty) {
        // Single sentence longer than chunkSize — force split.
        final forcedChunks = _forceSplit(
          sentences[sentenceIndex],
          documentId,
          currentStart,
        );
        chunks.addAll(forcedChunks);
        sentenceIndex++;
        currentStart += sentences[sentenceIndex - 1].length;
        overlapSentences = [];
        continue;
      }

      // Find the actual start index in the original text.
      final trimmed = currentContent.trim();
      currentStartIdx = text.indexOf(trimmed, currentStart);
      if (currentStartIdx == -1) currentStartIdx = currentStart;

      chunks.add(_makeChunk(
        id: _uuid.v4(),
        documentId: documentId,
        content: trimmed,
        startIndex: currentStartIdx,
        endIndex: currentStartIdx + trimmed.length,
      ));

      // Calculate overlap: carry forward the last N sentences whose
      // combined length is approximately the overlap size.
      overlapSentences = _calculateOverlapSentences(
        sentences,
        sentenceIndex,
      );

      // Advance start position past the non-overlapping portion.
      currentStart += trimmed.length - _overlapSentencesLength(overlapSentences);
      if (currentStart < 0) currentStart = 0;
    }
  }

  /// Splits text using fixed-size sliding windows.
  void _chunkWithFixedWindows(
    String text,
    String documentId,
    List<ChunkModel> chunks,
  ) {
    final step = config.chunkSize - config.overlapSize;
    var start = 0;

    while (start < text.length) {
      final end = math.min(start + config.chunkSize, text.length);
      final content = text.substring(start, end);

      chunks.add(_makeChunk(
        id: _uuid.v4(),
        documentId: documentId,
        content: content,
        startIndex: start,
        endIndex: end,
      ));

      if (end >= text.length) break;
      start += step;
    }
  }

  /// When a single sentence exceeds the chunk size, force-split it
  /// at word boundaries.
  List<ChunkModel> _forceSplit(
    String text,
    String documentId,
    int baseIndex,
  ) {
    final chunks = <ChunkModel>[];
    var start = 0;

    while (start < text.length) {
      var end = start + config.chunkSize;
      if (end >= text.length) {
        end = text.length;
      } else {
        // Try to break at a space.
        final breakPoint = text.lastIndexOf(' ', end);
        if (breakPoint > start + config.chunkSize ~/ 2) {
          end = breakPoint;
        }
      }

      chunks.add(_makeChunk(
        id: _uuid.v4(),
        documentId: documentId,
        content: text.substring(start, end).trim(),
        startIndex: baseIndex + start,
        endIndex: baseIndex + end,
      ));

      start = end - config.overlapSize;
      if (start < 0) start = 0;
      if (end >= text.length) break;
    }

    return chunks;
  }

  /// Returns the last few sentences whose combined length is close to
  /// the configured overlap size.
  List<String> _calculateOverlapSentences(
    List<String> allSentences,
    int nextIndex,
  ) {
    if (nextIndex <= 1) return [];

    final overlap = <String>[];
    var totalLength = 0;
    var i = nextIndex - 1;

    while (i >= 0 && totalLength < config.overlapSize) {
      overlap.insert(0, allSentences[i]);
      totalLength += allSentences[i].length + 1; // +1 for space
      i--;
    }

    return overlap;
  }

  int _overlapSentencesLength(List<String> sentences) {
    if (sentences.isEmpty) return 0;
    return sentences.join(' ').length;
  }

  /// Splits text into sentences using common delimiters.
  List<String> _splitIntoSentences(String text) {
    // Split on sentence-ending punctuation followed by whitespace or end.
    final regex = RegExp(r'(?<=[.!?])\s+');
    final parts = text.split(regex);

    return parts
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Creates a [ChunkModel] with the given parameters.
  ChunkModel _makeChunk({
    required String id,
    required String documentId,
    required String content,
    required int startIndex,
    required int endIndex,
  }) {
    return ChunkModel.unembedded(
      id: id,
      documentId: documentId,
      content: content,
      startIndex: startIndex,
      endIndex: endIndex,
    );
  }
}

