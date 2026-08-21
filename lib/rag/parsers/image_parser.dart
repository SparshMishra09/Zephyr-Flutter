/// Parser for image files with OCR text extraction.
///
/// Attempts to extract text from images using OCR. If OCR is unavailable,
/// falls back to returning a descriptive placeholder string.
library;

import 'dart:io';

import 'package:logging/logging.dart';

import 'base_parser.dart';

/// Extracts text from image files.
///
/// Supports common image formats: JPEG, PNG, GIF, BMP, WebP, TIFF.
///
/// **OCR Support:**
/// In production, integrate an OCR engine such as `google_ml_kit` or
/// `tesseract` for actual text recognition. This implementation provides
/// a placeholder that returns a description of the image file.
class ImageParser implements BaseParser {
  ImageParser();

  final Logger _logger = Logger('Zephyr.RAG.Parser.Image');

  /// MIME types handled by this parser.
  static const supportedTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/bmp',
    'image/webp',
    'image/tiff',
    'image/svg+xml',
  };

  @override
  String get supportedMimeType => 'image/jpeg';

  @override
  bool canHandle(String mimeType) {
    return supportedTypes.contains(mimeType) || mimeType.startsWith('image/');
  }

  @override
  Future<String> parse(String filePath) async {
    _logger.fine('Parsing image file: $filePath');

    try {
      final file = File(filePath);

      if (!await file.exists()) {
        throw FileNotFoundException('Image file not found: $filePath');
      }

      final fileSize = await file.length();
      final fileName = file.uri.pathSegments.last;

      // Attempt OCR text extraction.
      final ocrResult = await _performOcr(filePath);

      if (ocrResult.isNotEmpty) {
        _logger.fine('OCR extracted ${ocrResult.length} characters');
        return ocrResult;
      }

      // Fallback: return a descriptive placeholder.
      final placeholder = _buildPlaceholder(fileName, fileSize);
      _logger.info(
        'OCR returned no text; using placeholder description for: $fileName',
      );
      return placeholder;
    } on IOException catch (e) {
      throw ParserException('IO error reading image $filePath: $e');
    }
  }

  /// Performs OCR on the image at [filePath].
  ///
  /// Currently returns an empty string as a placeholder. Replace this
  /// with actual OCR integration:
  ///
  /// ```dart
  /// // Example with google_ml_kit:
  /// final inputImage = InputImage.fromFilePath(filePath);
  /// final text = await TextRecognizer.instance.processImage(inputImage);
  /// return text.text;
  /// ```
  Future<String> _performOcr(String filePath) async {
    // ── Placeholder OCR Implementation ────────────────────────────────
    //
    // TODO: Integrate an actual OCR engine.
    //
    // Option 1: Google ML Kit (on-device, free)
    //   - Add `google_ml_kit` to pubspec.yaml
    //   - Supports text recognition in 100+ languages
    //   - Works offline on device
    //
    // Option 2: Tesseract OCR
    //   - Add `tesseract` or `flutter_tesseract_ocr`
    //   - Open-source, supports many languages
    //   - Requires language data files
    //
    // Option 3: Cloud-based OCR
    //   - Google Cloud Vision API
    //   - AWS Textract
    //   - Azure Computer Vision
    //
    // For now, return empty to trigger the placeholder fallback.
    _logger.fine('OCR placeholder: no OCR engine configured');
    return '';
  }

  /// Builds a descriptive placeholder string for an image file.
  ///
  /// This provides context about the image even when OCR is unavailable,
  /// which can still be useful for retrieval (e.g. matching on file name).
  String _buildPlaceholder(String fileName, int fileSize) {
    final sizeKB = (fileSize / 1024).toStringAsFixed(1);
    final extension = fileName.split('.').last.toLowerCase();

    return '[Image: $fileName] '
        'Format: $extension | '
        'Size: ${sizeKB} KB | '
        'Note: OCR text extraction is not available. '
        'This image was indexed with a placeholder description.';
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