/// Parser for plain text-based file formats.
///
/// Supports `.txt`, `.md`, `.csv`, and `.json` files by reading them
/// as UTF-8 encoded text.
library;

import 'dart:io';

import 'package:logging/logging.dart';

import 'base_parser.dart';

/// Parses plain text files (.txt, .md, .csv, .json).
class TextParser implements BaseParser {
  TextParser({this.encoding = SystemEncoding.utf8});

  /// Text encoding used when reading files.
  final Encoding encoding;

  final Logger _logger = Logger('Zephyr.RAG.Parser.Text');

  /// MIME types handled by this parser.
  static const supportedTypes = {
    'text/plain',
    'text/markdown',
    'text/csv',
    'application/json',
  };

  @override
  String get supportedMimeType => 'text/plain';

  @override
  bool canHandle(String mimeType) {
    // Accept any text/* MIME type as a fallback.
    return supportedTypes.contains(mimeType) || mimeType.startsWith('text/');
  }

  @override
  Future<String> parse(String filePath) async {
    _logger.fine('Parsing text file: $filePath');

    try {
      final file = File(filePath);

      if (!await file.exists()) {
        throw FileNotFoundException('File not found: $filePath');
      }

      final content = await file.readAsString(encoding: encoding);
      _logger.fine('Read ${content.length} characters from: $filePath');

      return content;
    } on FormatException catch (e) {
      _logger.warning('Encoding error reading $filePath: $e');
      // Retry with latin1 as fallback.
      try {
        final file = File(filePath);
        return await file.readAsString(encoding: Encoding.latin1);
      } catch (e2) {
        throw ParserException(
          'Failed to parse text file $filePath. '
          'UTF-8 error: $e, Latin-1 error: $e2',
        );
      }
    } on IOException catch (e) {
      throw ParserException('IO error reading $filePath: $e');
    }
  }
}

/// Thrown when a file cannot be found.
class FileNotFoundException implements IOException {
  final String message;
  FileNotFoundException(this.message);
  @override
  String toString() => 'FileNotFoundException: $message';
}

/// Thrown when a parser fails to extract content.
class ParserException implements IOException {
  final String message;
  ParserException(this.message);
  @override
  String toString() => 'ParserException: $message';
}