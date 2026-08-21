/// Abstract base class for embedding generation.
///
/// Implementations of this interface convert raw text into dense vector
/// representations (embeddings) that can be compared for semantic
/// similarity at retrieval time.
library;

/// Contract that every embedding provider must fulfil.
abstract class EmbeddingGenerator {
  /// Generates a single embedding vector for the given [text].
  ///
  /// Returns a fixed-length list of doubles. The dimensionality is
  /// determined by the concrete implementation (commonly 384 or 768).
  Future<List<double>> generateEmbedding(String text);

  /// Generates embedding vectors for a batch of [texts].
  ///
  /// Implementations may optimise batch inference (e.g. by padding to
  /// the longest sequence and running a single forward pass).
  ///
  /// The returned list has the same length as [texts], with each element
  /// corresponding positionally.
  Future<List<List<double>>> generateEmbeddings(List<String> texts);

  /// Returns the dimensionality of vectors produced by this generator.
  int get dimensions;
}