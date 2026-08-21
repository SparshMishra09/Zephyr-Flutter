import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/rag/embedding/lite_embedder.dart';

void main() {
  group('LiteEmbedder', () {
    late LiteEmbedder embedder;

    setUp(() {
      embedder = LiteEmbedder();
    });

    test('generates embedding with consistent dimensions', () {
      final embedding = embedder.generateEmbeddingSync('Hello world');

      expect(embedding.length, equals(384));
      for (final val in embedding) {
        expect(val, isIn(RangeDouble(-1.0, 1.0)));
      }
    });

    test('same text produces same embedding', () {
      final text = 'Consistent embedding test';
      final emb1 = embedder.generateEmbeddingSync(text);
      final emb2 = embedder.generateEmbeddingSync(text);

      for (var i = 0; i < emb1.length; i++) {
        expect(emb1[i], closeTo(emb2[i], 0.0001));
      }
    });

    test('different texts produce different embeddings', () {
      final emb1 = embedder.generateEmbeddingSync('Hello world');
      final emb2 = embedder.generateEmbeddingSync('Goodbye moon');

      var different = false;
      for (var i = 0; i < emb1.length; i++) {
        if ((emb1[i] - emb2[i]).abs() > 0.0001) {
          different = true;
          break;
        }
      }
      expect(different, isTrue);
    });

    test('similar texts have higher similarity', () {
      final emb1 = embedder.generateEmbeddingSync('The dog is playing');
      final emb2 = embedder.generateEmbeddingSync('The dog is running');
      final emb3 = embedder.generateEmbeddingSync('The stock market crashed');

      final sim12 = LiteEmbedder.cosineSimilarity(emb1, emb2);
      final sim13 = LiteEmbedder.cosineSimilarity(emb1, emb3);

      // Similar sentences should have higher similarity
      expect(sim12, greaterThan(sim13));
    });

    test('identical texts have similarity of 1.0', () {
      final emb = embedder.generateEmbeddingSync('Identical text');
      final similarity = LiteEmbedder.cosineSimilarity(emb, emb);

      expect(similarity, closeTo(1.0, 0.0001));
    });

    test('embedding is normalized (unit vector)', () {
      final emb = embedder.generateEmbeddingSync('Normalization test');

      var magnitude = 0.0;
      for (final val in emb) {
        magnitude += val * val;
      }
      magnitude = magnitude.sqrt();

      expect(magnitude, closeTo(1.0, 0.01));
    });

    test('handles empty string', () {
      final emb = embedder.generateEmbeddingSync('');
      expect(emb.length, equals(384));
    });

    test('handles very long text', () {
      final longText = 'Word ' * 1000;
      final emb = embedder.generateEmbeddingSync(longText);

      expect(emb.length, equals(384));
    });

    test('handles unicode text', () {
      final emb = embedder.generateEmbeddingSync('你好世界 🌍 مرحبا');
      expect(emb.length, equals(384));
    });

    test('batch embedding generates correct number of results', () async {
      final texts = ['Text one', 'Text two', 'Text three'];
      final embeddings = await embedder.generateEmbeddings(texts);

      expect(embeddings.length, equals(3));
      for (final emb in embeddings) {
        expect(emb.length, equals(384));
      }
    });

    test('cosine similarity is symmetric', () {
      final emb1 = embedder.generateEmbeddingSync('Symmetric test A');
      final emb2 = embedder.generateEmbeddingSync('Symmetric test B');

      final simAB = LiteEmbedder.cosineSimilarity(emb1, emb2);
      final simBA = LiteEmbedder.cosineSimilarity(emb2, emb1);

      expect(simAB, closeTo(simBA, 0.0001));
    });
  });
}