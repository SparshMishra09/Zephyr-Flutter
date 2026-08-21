import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/rag/parsers/text_parser.dart';

void main() {
  group('TextParser', () {
    late TextParser parser;
    late Directory tempDir;
    late String tempFile;

    setUp(() async {
      parser = TextParser();
      tempDir = await Directory.systemTemp.create('zephyr_test_${DateTime.now().millisecondsSinceEpoch}');
      tempFile = '${tempDir.path}/test.txt';
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('parses plain text file', () async {
      final content = 'Hello, this is a test file.\nIt has multiple lines.\nThird line here.';
      await File(tempFile).writeAsString(content);

      final result = await parser.parse(tempFile);

      expect(result, contains('Hello'));
      expect(result, contains('test file'));
      expect(result, contains('Third line'));
    });

    test('parses markdown file', () async {
      final mdFile = '${tempDir.path}/test.md';
      final content = '''
# Test Document

This is a **markdown** document with some content.

- Item one
- Item two
- Item three

> A quote here

Some `code` and a [link](https://example.com).
''';
      await File(mdFile).writeAsString(content);

      final result = await parser.parse(mdFile);

      expect(result, contains('Test Document'));
      expect(result, contains('markdown'));
      expect(result, contains('Item one'));
    });

    test('parses CSV file', () async {
      final csvFile = '${tempDir.path}/test.csv';
      final content = '''name,age,city
Alice,30,New York
Bob,25,London
Charlie,35,Paris
''';
      await File(csvFile).writeAsString(content);

      final result = await parser.parse(csvFile);

      expect(result, contains('Alice'));
      expect(result, contains('Bob'));
      expect(result, contains('Charlie'));
    });

    test('handles empty file', () async {
      await File(tempFile).writeAsString('');
      final result = await parser.parse(tempFile);
      expect(result, isEmpty);
    });

    test('handles file with special characters', () async {
      final content = 'Special chars: @#$%^&*()_+-=[]{}|;:,.<>?/~`\nUnicode: 你好 🌍 مرحبا';
      await File(tempFile).writeAsString(content);

      final result = await parser.parse(tempFile);

      expect(result, contains('Special chars'));
      expect(result, contains('你好'));
    });

    test('throws on non-existent file', () async {
      expect(
        () async => parser.parse('/nonexistent/file.txt'),
        throwsA(isA<Exception>()),
      );
    });

    test('supportedMimeType returns text/plain', () {
      expect(parser.supportedMimeType, equals('text/plain'));
    });

    test('parses large file', () async {
      final largeContent = 'Line of text with some content. ' * 5000;
      await File(tempFile).writeAsString(largeContent);

      final result = await parser.parse(tempFile);

      expect(result.length, greaterThan(1000));
      expect(result, contains('Line of text'));
    });
  });
}