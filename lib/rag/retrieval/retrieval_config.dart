/// Configuration parameters for vector retrieval operations.
///
/// Controls how many results are returned, the minimum similarity
/// threshold, and whether hybrid search (combining vector + keyword)
/// is enabled.
library;

/// Configuration for retrieval operations.
class RetrievalConfig {
  /// Maximum number of results to return.
  ///
  /// Defaults to 5. Must be a positive integer.
  final int topK;

  /// Minimum cosine similarity score for a result to be included.
  ///
  /// Values range from 0.0 (no similarity) to 1.0 (identical).
  /// Results scoring below this threshold are filtered out.
  ///
  /// Defaults to 0.0 (no filtering).
  final double similarityThreshold;

  /// Absolute maximum number of results, regardless of [topK].
  ///
  /// Acts as a hard cap to prevent excessive result sets.
  /// Defaults to 20.
  final int maxResults;

  /// Whether to enable hybrid search combining vector similarity
  /// with keyword matching (BM25 or TF-IDF).
  ///
  /// When enabled, results are ranked by a weighted combination of
  /// vector scores and keyword relevance.
  ///
  /// Defaults to false.
  final bool enableHybridSearch;

  /// Weight for the vector similarity component in hybrid search.
  ///
  /// The keyword component weight is `1.0 - vectorWeight`.
  /// Ignored when [enableHybridSearch] is false.
  ///
  /// Defaults to 0.7 (70% vector, 30% keyword).
  final double vectorWeight;

  /// Optional metadata filters to apply during retrieval.
  ///
  /// Only chunks whose metadata matches all key-value pairs in this
  /// map will be considered. For example:
  /// ```dart
  /// {'documentId': 'abc123', 'section': 'introduction'}
  /// ```
  final Map<String, dynamic> metadataFilters;

  const RetrievalConfig({
    this.topK = 5,
    this.similarityThreshold = 0.0,
    this.maxResults = 20,
    this.enableHybridSearch = false,
    this.vectorWeight = 0.7,
    this.metadataFilters = const {},
  });

  /// Creates a configuration optimised for high-recall retrieval.
  ///
  /// Returns more results with a lower similarity threshold, useful
  /// when you want to cast a wide net.
  factory RetrievalConfig.highRecall({int topK = 10}) {
    return RetrievalConfig(
      topK: topK,
      similarityThreshold: 0.1,
      maxResults: topK * 2,
    );
  }

  /// Creates a configuration optimised for high-precision retrieval.
  ///
  /// Returns fewer results with a higher similarity threshold, useful
  /// when you need only the most relevant matches.
  factory RetrievalConfig.highPrecision({int topK = 3}) {
    return RetrievalConfig(
      topK: topK,
      similarityThreshold: 0.5,
      maxResults: topK,
    );
  }

  /// Returns a copy with the specified fields replaced.
  RetrievalConfig copyWith({
    int? topK,
    double? similarityThreshold,
    int? maxResults,
    bool? enableHybridSearch,
    double? vectorWeight,
    Map<String, dynamic>? metadataFilters,
  }) {
    return RetrievalConfig(
      topK: topK ?? this.topK,
      similarityThreshold: similarityThreshold ?? this.similarityThreshold,
      maxResults: maxResults ?? this.maxResults,
      enableHybridSearch: enableHybridSearch ?? this.enableHybridSearch,
      vectorWeight: vectorWeight ?? this.vectorWeight,
      metadataFilters: metadataFilters ?? this.metadataFilters,
    );
  }

  /// Validates the configuration.
  ///
  /// Throws [ArgumentError] if any value is out of range.
  void validate() {
    if (topK <= 0) {
      throw ArgumentError.value(topK, 'topK', 'Must be positive.');
    }
    if (maxResults < topK) {
      throw ArgumentError.value(
        maxResults,
        'maxResults',
        'Must be >= topK ($topK).',
      );
    }
    if (similarityThreshold < 0.0 || similarityThreshold > 1.0) {
      throw ArgumentError.value(
        similarityThreshold,
        'similarityThreshold',
        'Must be in range [0.0, 1.0].',
      );
    }
    if (vectorWeight < 0.0 || vectorWeight > 1.0) {
      throw ArgumentError.value(
        vectorWeight,
        'vectorWeight',
        'Must be in range [0.0, 1.0].',
      );
    }
  }

  @override
  String toString() =>
      'RetrievalConfig(topK: $topK, threshold: $similarityThreshold, '
      'maxResults: $maxResults, hybrid: $enableHybridSearch)';
}