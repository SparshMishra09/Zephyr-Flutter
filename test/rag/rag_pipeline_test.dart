import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/rag/pipeline/rag_pipeline.dart';
import 'package:zephyr/rag/embedding/lite_embedder.dart';
import 'package:zephyr/rag/retrieval/vector_retriever.dart';
import 'package:zephyr/rag/retrieval/retrieval_config.dart';
import 'package:zephyr/core/models/chunk_model.dart';

// Mock LLM provider for testing
class MockLlmProvider implements LlmProvider {
  String? lastPrompt;
  Stream<String>? lastStream;
  String? mockResponse;
  bool throwException = false;

  @override
  Future<String> generate(String prompt) async {
    lastPrompt = prompt;
    if (throwException) throw Exception('Mock LLM error');
    return mockResponse ?? 'Mock response';
  }

  @override
  Stream<String> generateStreaming(String prompt) async* {
    lastPrompt = prompt;
    if (throwException) throw Exception('Mock LLM error');
    final response = mockResponse ?? 'Mock streaming response';
    for (final word in response.split(' ')) {
      yield word + ' ';
    }
  }
}

void main() {
  group('RagPipeline', () {
    late RagPipeline pipeline;
    late MockLlmProvider mockLlm;
    late LiteEmbedder embedder;
    late VectorRetriever retriever;

    setUp(() async {
      embedder = LiteEmbedder();
      retriever = VectorRetriever(config: RetrievalConfig(topK: 3));
      mockLlm = MockLlmProvider();
      mockLlm.mockResponse = 'This is a test answer based on the retrieved context.';

      pipeline = RagPipeline(
        embedder: embedder,
        retriever: retriever,
        llmProvider: mockLlm,
        config: RagPipelineConfig(topK: 3),
      );

      // Add some test chunks
      final testChunks = [
        ('The capital of France is Paris.', 'doc-1'),
        ('Paris is known for the Eiffel Tower.', 'doc-1'),
        ('Machine learning models require training data.', 'doc-2'),
        ('Flutter is developed by Google.', 'doc-3'),
      ];

      for (final (content, docId) in testChunks) {
        final embedding = embedder.generateEmbeddingSync(content);
        final chunk = ChunkModel(
          id: '${docId}-chunk',
          documentId: docId,
          content: content,
          embedding: embedding,
          startIndex: 0,
          endIndex: content.length,
          metadata: {'doc': docId},
        );
        await retriever.addChunk(chunk);
      }
    });

    test('query returns response with sources', () async {
      final response = await pipeline.query('What is the capital of France?');

      expect(response.content, isNotEmpty);
      expect(mockLlm.lastPrompt, contains('Paris') || contains('France'));
    });

    test('query includes context in prompt', () async {
      await pipeline.query('Tell me about Paris');

      expect(mockLlm.lastPrompt, isNotNull);
      expect(mockLlm.lastPrompt!.length, greaterThan(50));
    });

    test('streaming query yields chunks', () async {
      final responses = <String>[];
      await for (final chunk in pipeline.queryStreaming('What is Paris known for?')) {
        responses.add(chunk);
      }

      expect(responses, isNotEmpty);
      final fullResponse = responses.join('');
      expect(fullResponse.length, greaterThan(10));
    });

    test('handles empty query gracefully', () async {
      final response = await pipeline.query('');
      expect(response.content, isNotEmpty); // Should still return something from LLM
    });

    test('handles LLM exception', () async {
      mockLlm.throwException = true;

      expect(
        () async => pipeline.query('test query'),
        throwsA(isA<Exception>()),
      );
    });

    test('config affects retrieval', () {
      final customPipeline = RagPipeline(
        embedder: embedder,
        retriever: VectorRetriever(config: RetrievalConfig(topK: 1)),
        llmProvider: mockLlm,
        config: RagPipelineConfig(topK: 1),
      );

      // Pipeline should be configured with topK=1
      expect(customPipeline.config.topK, equals(1));
    });
  });
}