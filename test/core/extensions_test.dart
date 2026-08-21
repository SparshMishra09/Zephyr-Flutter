import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/core/utils/extensions.dart';

void main() {
  group('String Extensions', () {
    test('capitalize returns capitalized string', () {
      expect('hello'.capitalize, equals('Hello'));
      expect('hello world'.capitalize, equals('Hello world'));
      expect(''.capitalize, equals(''));
    });

    test('fromNow returns relative time string', () {
      final now = DateTime.now();
      expect(now.fromNow, equals('just now'));

      final recent = now.subtract(const Duration(minutes: 5));
      expect(recent.fromNow, equals('5 minutes ago'));

      final yesterday = now.subtract(const Duration(days: 1));
      expect(yesterday.fromNow, equals('1 day ago'));
    });
  });

  group('List<double> Extensions', () {
    test('dotProduct calculates correctly', () {
      final a = [1.0, 2.0, 3.0];
      final b = [4.0, 5.0, 6.0];

      // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
      expect(a.dotProduct(b), closeTo(32.0, 0.0001));
    });

    test('norm calculates correctly', () {
      final v = [3.0, 4.0];
      // sqrt(9 + 16) = 5
      expect(v.norm, closeTo(5.0, 0.0001));
    });

    test('normalize returns unit vector', () {
      final v = [3.0, 4.0];
      final normalized = v.normalize;

      expect(normalized.norm, closeTo(1.0, 0.0001));
    });

    test('cosineSimilarity of identical vectors is 1.0', () {
      final v = [1.0, 2.0, 3.0];
      expect(v.cosineSimilarity(v), closeTo(1.0, 0.0001));
    });

    test('cosineSimilarity of orthogonal vectors is 0.0', () {
      final a = [1.0, 0.0, 0.0];
      final b = [0.0, 1.0, 0.0];
      expect(a.cosineSimilarity(b), closeTo(0.0, 0.0001));
    });

    test('cosineSimilarity of opposite vectors is -1.0', () {
      final a = [1.0, 0.0, 0.0];
      final b = [-1.0, 0.0, 0.0];
      expect(a.cosineSimilarity(b), closeTo(-1.0, 0.0001));
    });

    test('normalize handles zero vector gracefully', () {
      final v = [0.0, 0.0, 0.0];
      final normalized = v.normalize;
      expect(normalized, equals([0.0, 0.0, 0.0]));
    });
  });
}