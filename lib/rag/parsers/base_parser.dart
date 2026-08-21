/// Abstract interface for document parsers.
///
/// Each parser handles one or more MIME types and extracts plain text
/// content from the underlying file format.
library;

/// Contract that every document parser must fulfil.
abstract class BaseParser {
  /// The MIME type this parser handles (e.g. `text/plain`, `application/pdf`).
  String get supportedMimeType;

  /// Whether this parser can handle the given [mimeType].
  bool canHandle(String mimeType) => mimeType == supportedMimeType;

  /// Parses the file at [filePath] and returns its text content.
  ///
  /// Implementations should handle encoding issues gracefully and return
  /// the best-effort text extraction.
  Future<String> parse(String filePath);
}