import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/rag/retrieval/vector_retriever.dart';
import 'package:zephyr/rag/retrieval/retrieval_config.dart';
import 'package:zephyr/core/models/chunk_model.dart';
import 'package:zephyr/core/models/vector_search_result.dart';
import 'package:zephyr/rag/embedding/lite_embedder.dart';

void main() {
  group('VectorRetriever', () {
    late VectorRetriever retriever;
    late LiteEmbedder embedder;

    setUp(() {
      embedder = LiteEmbedder();
      retriever = VectorRetriever(
        config: RetrievalConfig(topK: 3),
      );
    });

    test('returns empty results when no chunks added', () async {
      final query = 'test query';
      final queryEmbedding = embedder.generateEmbeddingSync(query);
      final results = await retriever.search(queryEmbedding);

      expect(results, isEmpty);
    });

    test('returns relevant results after adding chunks', () async {
      // Add some chunks with embeddings
      final texts = [
        'The quick brown fox jumps over the lazy dog',
        'Machine learning is a subset of artificial intelligence',
        'Flutter is a UI toolkit for building apps',
        'Dogs are loyal pets that love to play',
        'Python is a popular programming language',
      ];

      for (var i = 0; i < texts.length; i++) {
        final embedding = embedder.generateEmbeddingSync(texts[i]);
        final chunk = ChunkModel(
          id: 'chunk-$i',
          documentId: 'doc-$i',
          content: texts[i],
          embedding: embedding,
          startIndex: 0,
          endIndex: texts[i].length,
          metadata: {'index': i},
        );
        await retriever.addChunk(chunk);
      }

      // Search for dog-related content
      final queryEmbedding = embedder.generateEmbeddingSync('dogs playing');
      final results = await retriever.search(queryEmbedding);

      expect(results, isNotEmpty);
      expect(results.length, lessThanOrEqualTo(3)); // topK

      // The top result should be dog-related
      final topResult = results.first;
      expect(
        topResult.content.toLowerCase().contains('dog') ||
            topResult.content.toLowerCase().contains('fox'),
        isTrue,
      );
    });

    test('respects topK limit', () async {
      for (var i = 0; i < 10; i++) {
        final embedding = embedder.generateEmbeddingSync('text $i');
        final chunk = ChunkModel(
          id: 'chunk-$i',
          documentId: 'doc-$i',
          content: 'text $i',
          embedding: embedding,
          startIndex: 0,
          endIndex: 6,
          metadata: {},
        );
        await retriever.addChunk(chunk);
      }

      final queryEmbedding = embedder.generateEmbeddingSync('text 0');
      final results = await retriever.search(queryEmbedding);

      expect(results.length, lessThanOrEqualTo(3));
    });

    test('results are sorted by similarity score', () async {
      final texts = ['Alpha text', 'Beta text', 'Gamma text'];

      for (var i = 0; i < texts.length; i++) {
        final embedding = embedder.generateEmbeddingSync(texts[i]);
        final chunk = ChunkModel(
          id: 'chunk-$i',
          documentId: 'doc-$i',
          content: texts[i],
          embedding: embedding,
          startIndex: 0,
          endIndex: texts[i].length,
          metadata: {},
        );
        await retriever.addChunk(chunk);
      }

      final queryEmbedding = embedder.generateEmbeddingSync('Alpha');
      final results = await retriever.search(queryEmbedding);

      if (results.length > 1) {
        for (var i = 0; i < results.length - 1; i++) {
          expect(results[i].score, greaterThanOrEqualTo(results[i + 1].score));
        }
      }
    });

    test('clear removes all chunks', () async {
      final embedding = embedder.generateEmbeddingSync('test');
      final chunk = ChunkModel(
        id: 'chunk-1',
        documentId: 'doc-1',
        content: 'test',
        embedding: embedding,
        startIndex: 0,
        endIndex: 4,
        metadata: {},
      );
      await retriever.addChunk(chunk);

      await retriever.clear();

      final results = await retriever.search(embedding);
      expect(results, isEmpty);
    });

    test('removes chunk by ID', () async {
      for (var i = 0; i < 3; i++) {
        final embedding = embedder.generateEmbeddingSync('text $i');
        final chunk = ChunkModel(
          id: 'chunk-$i',
          documentId: 'doc-$i',
          content: 'text $i',
          embedding: embedding,
          startIndex: 0,
          endIndex: 6,
          metadata: {},
        );
        await retriever.addChunk(chunk);
      }

      await retriever.removeChunk('chunk-1');

      final queryEmbedding = embedder.generateEmbeddingSync('text');
      final results = await retriever.search(queryEmbedding);

      final chunkIds = results.map((r) => r.chunkId).toList();
      expect(chunkIds.contains('chunk-1'), isFalse);
    });

    test('getChunkCount returns correct count', () async {
      expect(retriever.getChunkCount, equals(0));

      for (var i = 0; i < 5; i++) {
        final embedding = embedder.generateEmbeddingSync('text $i');
        final chunk = ChunkModel(
          id: 'chunk-$i',
          documentId: 'doc-$i',
          content: 'text $i',
          embedding: embedding,
          startIndex: 0,
          endIndex: 6,
          metadata: {},
        );
        await retriever.addChunk(chunk);
      }

      expect(retriever.getChunkCount, equals(5));
    });
  });

  group('RetrievalConfig', () {
    test('default config has sensible values', () {
      final config = RetrievalConfig();
      expect(config.topK, equals(5));
      expect(config.similarityThreshold, equals(0.5));
    });

    test('custom config overrides defaults', () {
      final config = RetrievalConfig(topK: 10, similarityThreshold: 0.8);
      expect(config.topK, equals(10));
      expect(config.similarityThreshold, equals(0.8));
    });

    test('factory constructors work', () {
      final highRecall = RetrievalConfig.highRecall();
      expect(highRecall.topK, greaterThan(5));

      final highPrecision = RetrievalConfig.highPrecision();
      expect(highPrecision.similarityThreshold, greaterThan(0.5));
    });
  });
}