/// Lightweight embedding implementation using TensorFlow Lite.
///
/// Attempts to load a TF Lite model from `assets/models/embedding.tflite`.
/// If the model is unavailable, falls back to a character n-gram (TF-IDF-like)
/// embedding that produces 384-dimensional vectors.
library;

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:logging/logging.dart';
import 'package:tensorflow_lite_flutter/tensorflow_lite_flutter.dart';

import 'embedding_generator.dart';

/// Lightweight embedding provider with TF Lite and n-gram fallback.
///
/// Create once and reuse across the application lifecycle. Call [close]
/// when the app shuts down to release the interpreter.
class LiteEmbedder implements EmbeddingGenerator {
  LiteEmbedder({this.modelAssetPath = 'assets/models/embedding.tflite'});

  /// Path to the TF Lite model within the Flutter asset bundle.
  final String modelAssetPath;

  final Logger _logger = Logger('Zephyr.RAG.LiteEmbedder');

  TensorflowLite? _interpreter;
  bool _modelLoaded = false;
  bool _initialised = false;

  @override
  int get dimensions => 384;

  /// Whether the TF Lite model is currently loaded and active.
  bool get isModelLoaded => _modelLoaded;

  /// Whether the embedder has been initialised (model attempted).
  bool get isInitialised => _initialised;

  // ── Lifecycle ───────────────────────────────────────────────────────

  /// Initialises the embedder by attempting to load the TF Lite model.
  ///
  /// If loading fails, the fallback n-gram method will be used silently.
  Future<void> initialise() async {
    if (_initialised) return;
    _initialised = true;

    try {
      await _loadModel();
      _modelLoaded = true;
      _logger.info('TF Lite embedding model loaded successfully.');
    } catch (e, st) {
      _logger.warning(
        'Failed to load TF Lite model; falling back to n-gram embeddings. '
        'Error: $e',
        e,
        st,
      );
      _modelLoaded = false;
    }
  }

  /// Releases the TF Lite interpreter.
  Future<void> close() async {
    if (_interpreter != null) {
      await _interpreter!.close();
      _interpreter = null;
    }
    _modelLoaded = false;
    _initialised = false;
    _logger.info('LiteEmbedder closed.');
  }

  // ── TF Lite loading ─────────────────────────────────────────────────

  Future<void> _loadModel() async {
    try {
      final model = TensorflowLiteModel.fromAsset(modelAssetPath);
      _interpreter = await TensorflowLite.initialize(model: model);
    } on Exception catch (_) {
      // Re-throw so the caller knows the model is unavailable.
      throw StateError(
        'Unable to load TF Lite model from $modelAssetPath. '
        'Ensure the model file exists in the asset bundle.',
      );
    }
  }

  // ── Embedding generation ────────────────────────────────────────────

  @override
  Future<List<double>> generateEmbedding(String text) async {
    if (!_initialised) await initialise();

    if (_modelLoaded && _interpreter != null) {
      return _generateWithTfLite(text);
    }

    return _generateNgramEmbedding(text);
  }

  @override
  Future<List<List<double>>> generateEmbeddings(List<String> texts) async {
    if (!_initialised) await initialise();

    if (_modelLoaded && _interpreter != null) {
      // Batch inference via TF Lite.
      final results = <List<double>>[];
      for (final text in texts) {
        results.add(await _generateWithTfLite(text));
      }
      return results;
    }

    // Fallback: generate n-gram embeddings for each text.
    return Future.wait(texts.map(_generateNgramEmbedding));
  }

  /// Runs the TF Lite interpreter on [text] and returns the embedding.
  Future<List<double>> _generateWithTfLite(String text) async {
    final inputs = <Tensor>[Tensor.create(_preprocessText(text))];
    final outputs = <Tensor>[Tensor.create(List<double>.filled(dimensions, 0.0))];

    await _interpreter!.invoke(inputs: inputs, outputs: outputs);

    final data = outputs[0].data.first as List<double>;
    return _normalize(data);
  }

  /// Simple text preprocessing: lowercase and trim.
  ///
  /// A real implementation would also tokenize and pad/truncate to the
  /// model's expected input shape.
  List<List<dynamic>> _preprocessText(String text) {
    // Placeholder: in a real model the input shape depends on the
    // specific embedding model (e.g. sentence-transformers).
    // Here we return a 1×N shape where N is the text length capped at 512.
    const maxLen = 512;
    final cleaned = text.toLowerCase().trim();
    final chars = cleaned.substring(0, math.min(cleaned.length, maxLen));
    final row = chars.runes.map((r) => r.toDouble()).toList();
    // Pad to maxLen.
    while (row.length < maxLen) {
      row.add(0.0);
    }
    return [row];
  }

  // ── N-gram fallback ─────────────────────────────────────────────────

  /// Generates a 384-dimensional embedding using character 3-gram
  /// frequency vectors, L2-normalised.
  ///
  /// This is a simple but surprisingly effective fallback that captures
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

  /// L2-normalises a vector in-place and returns it.
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