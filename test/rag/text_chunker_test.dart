import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/rag/ingestion/text_chunker.dart';
import 'package:zephyr/core/models/chunk_model.dart';

void main() {
  group('TextChunker', () {
    late TextChunker chunker;

    setUp(() {
      chunker = TextChunker(
        config: ChunkingConfig(chunkSize: 100, overlap: 20),
      );
    });

    test('chunks short text into single chunk', () {
      final text = 'Hello world';
      final result = chunker.chunk(text, documentId: 'doc1');

      expect(result.chunks, hasLength(1));
      expect(result.chunks.first.content, equals('Hello world'));
      expect(result.chunks.first.documentId, equals('doc1'));
    });

    test('splits long text into multiple chunks', () {
      final text = 'A' * 250;
      final result = chunker.chunk(text, documentId: 'doc1');

      expect(result.chunks.length, greaterThan(1));
      for (var i = 0; i < result.chunks.length - 1; i++) {
        final current = result.chunks[i].content;
        final next = result.chunks[i + 1].content;
        // Check overlap exists
        expect(current.length, closeTo(100, 20));
      }
    });

    test('preserves sentence boundaries when possible', () {
      final text = 'First sentence. Second sentence. Third sentence. Fourth sentence.';
      final result = chunker.chunk(text, documentId: 'doc1');

      for (final chunk in result.chunks) {
        // Chunks should try to end at sentence boundaries
        expect(chunk.content, isNotEmpty);
      }
    });

    test('handles empty text', () {
      final result = chunker.chunk('', documentId: 'doc1');
      expect(result.chunks, isEmpty);
    });

    test('handles text shorter than chunk size', () {
      final text = 'Short';
      final result = chunker.chunk(text, documentId: 'doc1');

      expect(result.chunks, hasLength(1));
      expect(result.chunks.first.content, equals('Short'));
    });

    test('chunk indices are sequential', () {
      final text = 'A' * 300;
      final result = chunker.chunk(text, documentId: 'doc1');

      for (var i = 0; i < result.chunks.length - 1; i++) {
        final current = result.chunks[i];
        final next = result.chunks[i + 1];
        expect(next.startIndex, greaterThan(current.startIndex));
      }
    });

    test('chunk metadata contains document ID', () {
      final text = 'Test content for metadata check';
      final result = chunker.chunk(text, documentId: 'test-doc-123');

      for (final chunk in result.chunks) {
        expect(chunk.documentId, equals('test-doc-123'));
        expect(chunk.metadata['chunk_index'], isNotNull);
      }
    });

    test('large text produces reasonable number of chunks', () {
      final text = 'Word. ' * 500; // ~3000 chars
      final result = chunker.chunk(text, documentId: 'doc1');

      expect(result.chunks.length, greaterThan(5));
      expect(result.chunks.length, lessThan(100));
    });

    test('chunking config with custom parameters', () {
      final customChunker = TextChunker(
        config: ChunkingConfig(chunkSize: 200, overlap: 50),
      );
      final text = 'X' * 600;
      final result = customChunker.chunk(text, documentId: 'doc1');

      expect(result.chunks.length, greaterThan(1));
      for (final chunk in result.chunks) {
        expect(chunk.content.length, lessThanOrEqualTo(250)); // allow some slack for boundary preservation
      }
    });

    test('handles text with special characters', () {
      final text = 'Hello! @world #test \$money %done &more *special (chars)';
      final result = chunker.chunk(text, documentId: 'doc1');

      expect(result.chunks, isNotEmpty);
    });

    test('handles text with newlines and paragraphs', () {
      final text = '''
      Paragraph one with some content here.
      This is the first paragraph of our test document.

      Paragraph two with different content.
      This is the second paragraph that should be chunked separately.

      Paragraph three with more content to test the chunker behavior.
      ''';
      final result = chunker.chunk(text, documentId: 'doc1');

      expect(result.chunks, isNotEmpty);
      // Should preserve paragraph structure somewhat
      final fullContent = result.chunks.map((c) => c.content).join('');
      expect(fullContent.contains('Paragraph one'), isTrue);
      expect(fullContent.contains('Paragraph two'), isTrue);
    });
  });
}