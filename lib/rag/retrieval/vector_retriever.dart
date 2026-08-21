/// Vector similarity search over stored text chunks.
///
/// Supports exact cosine similarity search for small datasets and
/// approximate nearest neighbor (ANN) search for larger collections.
library;

import 'dart:math' as math;

import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

import '../../core/database/app_database.dart';
import '../../core/models/vector_search_result.dart';
import '../embedding/lite_embedder.dart';
import 'retrieval_config.dart';

/// Result of a vector search operation with metadata.
class SearchResult {
  /// The matching result.
  final VectorSearchResult result;

  /// Rank position (1-based).
  final int rank;

  const SearchResult({required this.result, required this.rank});

  @override
  String toString() => '#$rank ${result.chunkId} (${result.score.toStringAsFixed(4)})';
}

/// Performs vector similarity search over stored chunks.
///
/// Loads chunks from the Hive [chunksBox] and compares query embeddings
/// against stored embeddings using cosine similarity.
///
/// For datasets larger than [annThreshold], switches to an approximate
/// nearest neighbor algorithm using locality-sensitive hashing (LSH)
/// for better performance.
class VectorRetriever {
  VectorRetriever({
    this.annThreshold = 1000,
  });

  /// Number of chunks at which to switch from exact to ANN search.
  final int annThreshold;

  final Logger _logger = Logger('Zephyr.RAG.Retriever');

  /// Cached list of all chunks for faster iteration.
  /// Populated on first search or when [refreshCache] is called.
  List<Map<String, dynamic>> _cachedChunks = [];
  bool _cacheLoaded = false;

  /// Refreshes the in-memory cache of chunks from the database.
  Future<void> refreshCache() async {
    final db = AppDatabase();
    final box = db.chunksBox;

    _cachedChunks = box.values
        .whereType<Map<String, dynamic>>()
        .where((m) => (m['embedding'] as List?)?.isNotEmpty ?? false)
        .toList();

    _cacheLoaded = true;
    _logger.info('Cache refreshed: ${_cachedChunks.length} chunks loaded');
  }

  /// Searches for the most similar chunks to the query embedding.
  ///
  /// [queryEmbedding] is the dense vector representing the user's query.
  /// [config] controls retrieval behaviour (topK, thresholds, etc.).
  ///
  /// Returns results sorted by descending similarity score.
  Future<List<SearchResult>> search(
    List<double> queryEmbedding, {
    RetrievalConfig config = const RetrievalConfig(),
  }) async {
    config.validate();

    if (!_cacheLoaded) {
      await refreshCache();
    }

    if (_cachedChunks.isEmpty) {
      _logger.warning('No chunks available for search');
      return [];
    }

    // Apply metadata filters first.
    final filtered = _applyMetadataFilters(_cachedChunks, config.metadataFilters);

    if (filtered.isEmpty) {
      _logger.fine('No chunks match metadata filters');
      return [];
    }

    // Choose search strategy based on dataset size.
    List<VectorSearchResult> results;
    if (filtered.length > annThreshold) {
      results = await _approximateNearestNeighbors(
        queryEmbedding,
        filtered,
        config,
      );
    } else {
      results = _exactCosineSearch(
        queryEmbedding,
        filtered,
        config,
      );
    }

    // Apply similarity threshold filter.
    results = results
        .where((r) => r.score >= config.similarityThreshold)
        .toList();

    // Cap at maxResults.
    if (results.length > config.maxResults) {
      results = results.sublist(0, config.maxResults);
    }

    // Wrap with rank.
    final searchResults = results.asMap().entries.map((entry) {
      return SearchResult(
        result: entry.value,
        rank: entry.key + 1,
      );
    }).toList();

    _logger.fine(
      'Search returned ${searchResults.length} results '
      '(threshold: ${config.similarityThreshold})',
    );

    return searchResults;
  }

  /// Exact cosine similarity search over all chunks.
  ///
  /// Computes the cosine similarity between the query and every chunk,
  /// then returns the top-K results.
  List<VectorSearchResult> _exactCosineSearch(
    List<double> queryEmbedding,
    List<Map<String, dynamic>> chunks,
    RetrievalConfig config,
  ) {
    final scored = <(double, Map<String, dynamic>)>[];

    for (final chunk in chunks) {
      final embedding = (chunk['embedding'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();

      final score = LiteEmbedder.cosineSimilarity(queryEmbedding, embedding);
      scored.add((score, chunk));
    }

    // Sort descending by score.
    scored.sort((a, b) => b.$1.compareTo(a.$1));

    // Take top-K.
    final topK = math.min(config.topK, scored.length);
    return scored.take(topK).map((entry) {
      return _mapToResult(entry.$2, entry.$1);
    }).toList();
  }

  /// Approximate nearest neighbor search using LSH-style bucketing.
  ///
  /// For large datasets, exact search becomes O(n). This method
  /// partitions the vector space into buckets and only searches
  /// nearby buckets, trading some recall for speed.
  Future<List<VectorSearchResult>> _approximateNearestNeighbors(
    List<double> queryEmbedding,
    List<Map<String, dynamic>> chunks,
    RetrievalConfig config,
  ) async {
    const numBuckets = 64;
    const numProbes = 8; // Number of nearby buckets to search.

    // Create buckets based on quantised vector dimensions.
    final buckets = <int, List<Map<String, dynamic>>>{
      for (var i = 0; i < numBuckets; i++) i: [],
    };

    for (final chunk in chunks) {
      final embedding = (chunk['embedding'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      final bucketIdx = _quantizeToBucket(embedding, numBuckets);
      buckets[bucketIdx]!.add(chunk);
    }

    // Find the query's bucket and probe nearby buckets.
    final queryBucket = _quantizeToBucket(queryEmbedding, numBuckets);
    final probeBuckets = _getNearbyBuckets(queryBucket, numBuckets, numProbes);

    // Collect candidates from probed buckets.
    final candidates = <Map<String, dynamic>>{};
    for (final idx in probeBuckets) {
      candidates.addAll(buckets[idx] ?? []);
    }

    _logger.fine(
      'ANN: probing $numProbes buckets, found ${candidates.length} candidates '
      'out of ${chunks.length} total',
    );

    // Score candidates exactly.
    return _exactCosineSearch(queryEmbedding, candidates.toList(), config);
  }

  /// Quantises a vector to a bucket index.
  int _quantizeToBucket(List<double> vector, int numBuckets) {
    // Use the first dimension as the primary hash.
    // Normalize from [-1, 1] to [0, numBuckets).
    final val = vector.isNotEmpty ? vector[0] : 0.0;
    final normalised = (val + 1.0) / 2.0; // Shift to [0, 1].
    return ((normalised * numBuckets).floor()) % numBuckets;
  }

  /// Returns indices of nearby buckets in a circular space.
  List<int> _getNearbyBuckets(
    int center,
    int totalBuckets,
    int numProbes,
  ) {
    final buckets = <int>{center};

    for (var radius = 1; buckets.length < numProbes && radius < totalBuckets; radius++) {
      buckets.add((center + radius) % totalBuckets);
      if (buckets.length < numProbes) {
        buckets.add((center - radius + totalBuckets) % totalBuckets);
      }
    }

    return buckets.take(numProbes).toList();
  }

  /// Filters chunks by metadata key-value pairs.
  List<Map<String, dynamic>> _applyMetadataFilters(
    List<Map<String, dynamic>> chunks,
    Map<String, dynamic> filters,
  ) {
    if (filters.isEmpty) return chunks;

    return chunks.where((chunk) {
      final metadata = (chunk['metadata'] as Map<String, dynamic>?) ?? {};

      for (final entry in filters.entries) {
        if (!metadata.containsKey(entry.key)) return false;
        if (metadata[entry.key] != entry.value) return false;
      }

      return true;
    }).toList();
  }

  /// Converts a chunk map to a [VectorSearchResult].
  VectorSearchResult _mapToResult(Map<String, dynamic> map, double score) {
    return VectorSearchResult(
      chunkId: map['id'] as String,
      documentId: map['documentId'] as String,
      score: score,
      content: map['content'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }
}