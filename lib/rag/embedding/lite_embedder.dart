/// Lightweight embedding implementation using character n-gram vectors.
///
/// Produces 384-dimensional vectors using character 3-gram frequency
/// hashing (similar to TF-HASH). No external model required — works
/// entirely on-device with zero dependencies.
library;

import 'dart:math' as math;
import 'package:logging/logging.dart';

import 'embedding_generator.dart';

/// Lightweight embedding provider using character n-gram hashing.
///
/// Create once and reuse across the application lifecycle.
/// No model to load — ready to use immediately.
class LiteEmbedder implements EmbeddingGenerator {
  LiteEmbedder();

  final Logger _logger = Logger('Zephyr.RAG.LiteEmbedder');

  @override
  int get dimensions => 384;

  /// Whether the embedder is ready (always true for n-gram fallback).
  bool get isInitialised => true;

  // ── Embedding generation ────────────────────────────────────────────

  @override
  Future<List<double>> generateEmbedding(String text) async {
    return _generateNgramEmbedding(text);
  }

  @override
  Future<List<List<double>>> generateEmbeddings(List<String> texts) async {
    return Future.wait(texts.map(_generateNgramEmbedding));
  }

  /// Generates a 384-dimensional embedding using character 3-gram
  /// frequency vectors, L2-normalised.
  ///
  /// This is a simple but effective approach that captures
  /// local character patterns without any external model.
  List<double> _generateNgramEmbedding(String text) {
    const dim = 384;
    final cleaned = text.toLowerCase().trim();

    if (cleaned.isEmpty) {
      return List<double>.filled(dim, 0.0);
    }

    // Count character 3-grams.
    final ngramCounts = <String, int>{};
    for (var i = 0; i <= cleaned.length - 3; i++) {
      final ngram = cleaned.substring(i, i + 3);
      ngramCounts[ngram] = (ngramCounts[ngram] ?? 0) + 1;
    }

    if (ngramCounts.isEmpty) {
      return List<double>.filled(dim, 0.0);
    }

    // Hash each n-gram into a bucket index (0..dim-1).
    final vector = List<double>.filled(dim, 0.0);
    for (final entry in ngramCounts.entries) {
      final idx = _hashNgram(entry.key) % dim;
      // Use TF-IDF-like weighting: count / total_ngrams.
      vector[idx] += entry.value / ngramCounts.length;
    }

    return _normalize(vector);
  }

  /// Hashes a character n-gram string to an integer.
  int _hashNgram(String ngram) {
    int hash = 5381;
    for (var i = 0; i < ngram.length; i++) {
      hash = ((hash << 5) + hash + ngram.codeUnitAt(i)) & 0x7fffffff;
    }
    return hash;
  }

  // ── Utility ─────────────────────────────────────────────────────────

  /// L2-normalises a vector and returns it.
  static List<double> _normalize(List<double> vector) {
    var magnitude = 0.0;
    for (final v in vector) {
      magnitude += v * v;
    }
    magnitude = math.sqrt(magnitude);

    if (magnitude < 1e-12) {
      return List<double>.filled(vector.length, 0.0);
    }

    return vector.map((v) => v / magnitude).toList();
  }

  /// Computes the cosine similarity between two vectors.
  ///
  /// Both vectors must have the same length. If either vector has zero
  /// magnitude, returns 0.0.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError(
        'Vector dimensions must match: ${a.length} vs ${b.length}.',
      );
    }

    var dotProduct = 0.0;
    var magA = 0.0;
    var magB = 0.0;

    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }

    magA = math.sqrt(magA);
    magB = math.sqrt(magB);

    if (magA < 1e-12 || magB < 1e-12) {
      return 0.0;
    }

    return dotProduct / (magA * magB);
  }
}