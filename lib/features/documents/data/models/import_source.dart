/// Enum representing the different sources from which documents can be
/// imported into Zephyr.
library;

/// The method used to import a document into the knowledge base.
enum ImportSource {
  /// User selected files via the native file picker dialog.
  file_picker,

  /// Document was shared from another app via the system share intent.
  share_intent,

  /// Content was pasted from the device clipboard.
  clipboard,

  /// Document was captured using the device camera (e.g. scanning).
  camera,
}

/// Extension providing human-readable labels and icons for each source.
extension ImportSourceExtension on ImportSource {
  /// A user-friendly label for this import source.
  String get label {
    switch (this) {
      case ImportSource.file_picker:
        return 'File Picker';
      case ImportSource.share_intent:
        return 'Share';
      case ImportSource.clipboard:
        return 'Clipboard';
      case ImportSource.camera:
        return 'Camera';
    }
  }
}