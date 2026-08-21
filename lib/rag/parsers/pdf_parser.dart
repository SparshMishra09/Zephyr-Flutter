/// Parser for PDF documents.
///
/// Extracts text content from PDF files using the `pdf` package.
/// Falls back to a best-effort binary-to-text extraction if the
/// standard approach fails.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import 'base_parser.dart';

/// Parses PDF files and extracts their text content.
///
/// This parser reads the PDF structure and extracts text from each page.
/// For production use, consider adding `pdfx` or `syncfusion_flutter_pdf`
/// for more robust PDF text extraction.
class PdfParser implements BaseParser {
  PdfParser();

  final Logger _logger = Logger('Zephyr.RAG.Parser.Pdf');

  @override
  String get supportedMimeType => 'application/pdf';

  @override
  bool canHandle(String mimeType) => mimeType == 'application/pdf';

  @override
  Future<String> parse(String filePath) async {
    _logger.fine('Parsing PDF file: $filePath');

    try {
      final file = File(filePath);

      if (!await file.exists()) {
        throw FileNotFoundException('PDF file not found: $filePath');
      }

      final bytes = await file.readAsBytes();

      if (_isPdf(bytes)) {
        return await _extractTextFromPdf(bytes);
      } else {
        throw ParserException(
          'File does not appear to be a valid PDF: $filePath',
        );
      }
    } on IOException catch (e) {
      throw ParserException('IO error reading PDF $filePath: $e');
    }
  }

  /// Checks if the byte array starts with the PDF magic number.
  bool _isPdf(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46;   // F
  }

  /// Extracts text content from a PDF byte array.
  ///
  /// This implementation attempts to extract text by parsing the PDF
  /// stream objects. For production-grade extraction, integrate a
  /// dedicated PDF library such as `pdfx`.
  Future<String> _extractTextFromPdf(Uint8List bytes) async {
    final textSegments = <String>[];

    try {
      // Strategy 1: Try to extract text from PDF stream objects.
      // PDF text is typically stored in stream objects between
      // `stream` and `endstream` markers, using operators like
      // `Tj`, `TJ`, and `'` for text showing.
      final content = String.fromCharCodes(bytes);

      // Extract text from BT...ET (text object) blocks.
      final textObjectRegex = RegExp(r'BT\s(.*?)\sET', dotAll: true);
      final textObjects = textObjectRegex.allMatches(content);

      for (final obj in textObjects) {
        final block = obj.group(1) ?? '';
        // Extract strings from ( ... ) which contain actual text.
        final stringRegex = RegExp(r'\(([^)]*)\)');
        final strings = stringRegex.allMatches(block);

        for (final s in strings) {
          final text = s.group(1) ?? '';
          if (text.trim().isNotEmpty) {
            textSegments.add(_decodePdfText(text));
          }
        }

        // Also try to extract from [ ... ] TJ arrays.
        final tjRegex = RegExp(r'\[([^\]]*)\]\s*TJ');
        final tjMatches = tjRegex.allMatches(block);
        for (final tj in tjMatches) {
          final arrayContent = tj.group(1) ?? '';
          final tjStrings = RegExp(r'\(([^)]*)\)').allMatches(arrayContent);
          for (final ts in tjStrings) {
            final text = ts.group(1) ?? '';
            if (text.trim().isNotEmpty) {
              textSegments.add(_decodePdfText(text));
            }
          }
        }
      }

      if (textSegments.isNotEmpty) {
        _logger.fine(
          'Extracted ${textSegments.length} text segments from PDF',
        );
        return textSegments.join('\n');
      }

      _logger.warning(
        'No text segments found via stream parsing. '
        'PDF may use embedded fonts or be scanned.',
      );
    } catch (e) {
      _logger.warning('PDF stream parsing failed: $e');
    }

    // Strategy 2: Fallback — try to extract any readable text.
    // This catches simple PDFs where text appears as plain strings.
    final fallbackRegex = RegExp(r'\((.{10,})\)');
    final fallbackMatches = fallbackRegex.allMatches(
      String.fromCharCodes(bytes),
    );

    final fallbackTexts = fallbackMatches
        .map((m) => m.group(1) ?? '')
        .where((t) => _looksLikeText(t))
        .toList();

    if (fallbackTexts.isNotEmpty) {
      return fallbackTexts.join('\n');
    }

    throw ParserException(
      'Could not extract text from PDF. '
      'The file may be scanned (image-only) or use unsupported encoding. '
      'Consider using OCR for scanned documents.',
    );
  }

  /// Decodes common PDF text encoding escapes.
  String _decodePdfText(String text) {
    return text
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', '\\');
  }

  /// Heuristic: does this string look like natural language text?
  bool _looksLikeText(String s) {
    // Must contain mostly printable ASCII characters.
    final printable = RegExp(r'^[\x20-\x7E\s]+$');
    if (!printable.hasMatch(s)) return false;

    // Must have at least one space (indicating words).
    if (!s.contains(' ')) return false;

    // Should not look like binary garbage (too many special chars).
    final specialRatio = s.replaceAll(RegExp(r'[\w\s.,;:!?\'"-]'), '').length /
        s.length;
    return specialRatio < 0.3;
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