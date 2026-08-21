import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/core/models/document_model.dart';
import 'package:zephyr/core/models/chunk_model.dart';
import 'package:zephyr/core/models/conversation_model.dart';
import 'package:zephyr/core/models/message_model.dart';
import 'package:zephyr/core/models/vector_search_result.dart';

void main() {
  group('DocumentModel', () {
    test('creates document with initial values', () {
      final doc = DocumentModel.initial();
      expect(doc.id, isEmpty);
      expect(doc.status, equals(DocumentStatus.indexing));
      expect(doc.chunkCount, equals(0));
    });

    test('serializes and deserializes correctly', () {
      final doc = DocumentModel(
        id: 'doc-1',
        title: 'Test Document',
        path: '/path/to/doc.pdf',
        mimeType: 'application/pdf',
        fileSize: 1024,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        chunkCount: 10,
        status: DocumentStatus.indexed,
      );

      final map = doc.toMap();
      final restored = DocumentModel.fromMap(map);

      expect(restored.id, equals(doc.id));
      expect(restored.title, equals(doc.title));
      expect(restored.path, equals(doc.path));
      expect(restored.mimeType, equals(doc.mimeType));
      expect(restored.fileSize, equals(doc.fileSize));
      expect(restored.chunkCount, equals(doc.chunkCount));
      expect(restored.status, equals(doc.status));
    });

    test('copyWith creates modified copy', () {
      final doc = DocumentModel.initial();
      final updated = doc.copyWith(title: 'New Title', status: DocumentStatus.indexed);

      expect(updated.title, equals('New Title'));
      expect(updated.status, equals(DocumentStatus.indexed));
      expect(updated.id, equals(doc.id)); // unchanged
    });
  });

  group('ChunkModel', () {
    test('creates chunk with unembedded factory', () {
      final chunk = ChunkModel.unembedded(
        id: 'chunk-1',
        documentId: 'doc-1',
        content: 'Test content',
        startIndex: 0,
        endIndex: 12,
      );

      expect(chunk.id, equals('chunk-1'));
      expect(chunk.embedding, isEmpty);
      expect(chunk.content, equals('Test content'));
    });

    test('serializes and deserializes with embedding', () {
      final embedding = [0.1, 0.2, 0.3, 0.4, 0.5];
      final chunk = ChunkModel(
        id: 'chunk-1',
        documentId: 'doc-1',
        content: 'Test content',
        embedding: embedding,
        startIndex: 0,
        endIndex: 12,
        metadata: {'key': 'value'},
      );

      final map = chunk.toMap();
      final restored = ChunkModel.fromMap(map);

      expect(restored.id, equals(chunk.id));
      expect(restored.embedding, equals(embedding));
      expect(restored.metadata['key'], equals('value'));
    });

    test('copyWith updates fields', () {
      final chunk = ChunkModel.unembedded(
        id: 'chunk-1',
        documentId: 'doc-1',
        content: 'Original',
        startIndex: 0,
        endIndex: 8,
      );

      final updated = chunk.copyWith(embedding: [1.0, 2.0, 3.0]);
      expect(updated.embedding, equals([1.0, 2.0, 3.0]));
      expect(updated.content, equals('Original'));
    });
  });

  group('ConversationModel', () {
    test('creates initial conversation', () {
      final conv = ConversationModel.initial();
      expect(conv.id, isEmpty);
      expect(conv.messageCount, equals(0));
      expect(conv.isPinned, isFalse);
    });

    test('serializes and deserializes correctly', () {
      final conv = ConversationModel(
        id: 'conv-1',
        title: 'Test Conversation',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        messageCount: 5,
        isPinned: true,
      );

      final map = conv.toMap();
      final restored = ConversationModel.fromMap(map);

      expect(restored.id, equals(conv.id));
      expect(restored.title, equals(conv.title));
      expect(restored.isPinned, isTrue);
      expect(restored.messageCount, equals(5));
    });
  });

  group('MessageModel', () {
    test('creates user message with factory', () {
      final msg = MessageModel.user(
        id: 'msg-1',
        conversationId: 'conv-1',
        content: 'Hello!',
      );

      expect(msg.role, equals(MessageRole.user));
      expect(msg.content, equals('Hello!'));
      expect(msg.sources, isEmpty);
      expect(msg.isStreaming, isFalse);
    });

    test('creates assistant message with factory', () {
      final msg = MessageModel.assistant(
        id: 'msg-2',
        conversationId: 'conv-1',
        content: 'Hi there!',
        sources: ['chunk-1', 'chunk-2'],
      );

      expect(msg.role, equals(MessageRole.assistant));
      expect(msg.sources, hasLength(2));
    });

    test('serializes and deserializes correctly', () {
      final msg = MessageModel(
        id: 'msg-1',
        conversationId: 'conv-1',
        role: MessageRole.assistant,
        content: 'Test response',
        timestamp: DateTime(2024, 1, 1),
        sources: ['chunk-1'],
        isStreaming: false,
      );

      final map = msg.toMap();
      final restored = MessageModel.fromMap(map);

      expect(restored.id, equals(msg.id));
      expect(restored.role, equals(msg.role));
      expect(restored.content, equals(msg.content));
      expect(restored.sources, equals(msg.sources));
    });
  });

  group('VectorSearchResult', () {
    test('creates result with all fields', () {
      final result = VectorSearchResult(
        chunkId: 'chunk-1',
        documentId: 'doc-1',
        score: 0.95,
        content: 'Relevant content here',
        metadata: {'section': 'intro'},
      );

      expect(result.chunkId, equals('chunk-1'));
      expect(result.score, equals(0.95));
      expect(result.metadata['section'], equals('intro'));
    });

    test('toString returns readable output', () {
      final result = VectorSearchResult(
        chunkId: 'chunk-1',
        documentId: 'doc-1',
        score: 0.95,
        content: 'Test',
        metadata: {},
      );

      final str = result.toString();
      expect(str.contains('chunk-1'), isTrue);
      expect(str.contains('0.95'), isTrue);
    });
  });
}