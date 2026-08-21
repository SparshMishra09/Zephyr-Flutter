/// Application-wide constants: route names, permission strings, MIME types,
/// and UI-related values.
///
/// Centralising these strings makes it easy to rename routes or adjust
/// thresholds in a single place.
library;

// ── Route names ───────────────────────────────────────────────────────

/// Named routes used by the [GoRouter] / [Navigator].
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String chatDetail = '/chat/:conversationId';
  static const String documents = '/documents';
  static const String documentDetail = '/documents/:documentId';
  static const String settings = '/settings';
  static const String onboarding = '/onboarding';
}

// ── Permission strings ────────────────────────────────────────────────

/// Android / iOS permission identifiers.
class AppPermissions {
  AppPermissions._();

  /// Access to the device storage for importing documents.
  static const String storage = 'storage';

  /// Access to the camera (for scanning documents).
  static const String camera = 'camera';

  /// Access to the microphone (for voice input).
  static const String microphone = 'microphone';
}

// ── MIME type constants ───────────────────────────────────────────────

/// Supported document MIME types for ingestion.
class MimeTypes {
  MimeTypes._();

  static const String pdf = 'application/pdf';
  static const String txt = 'text/plain';
  static const String csv = 'text/csv';
  static const String html = 'text/html';
  static const String markdown = 'text/markdown';
  static const String json = 'application/json';
  static const String xml = 'application/xml';
  static const String docx =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  static const String pptx =
      'application/vnd.openxmlformats-officedocument.presentationml.presentation';
  static const String xlsx =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// All MIME types that Zephyr can ingest.
  static const List<String> supported = [
    pdf,
    txt,
    csv,
    html,
    markdown,
    json,
    xml,
    docx,
    pptx,
    xlsx,
  ];
}

// ── UI constants ──────────────────────────────────────────────────────

/// Shared UI sizing, timing, and colour tokens.
class UIConstants {
  UIConstants._();

  // ── Spacing ────────────────────────────────────────────────────────

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // ── Border radius ──────────────────────────────────────────────────

  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusFull = 9999.0;

  // ── Animation durations ────────────────────────────────────────────

  static const Duration animationShort = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationLong = Duration(milliseconds: 500);

  // ── Chat bubbles ───────────────────────────────────────────────────

  static const double chatBubbleMaxWidth = 0.85; // fraction of screen width
  static const int maxSourcePreviewChars = 200;

  // ── Misc ───────────────────────────────────────────────────────────

  /// Maximum number of conversations to show before pagination.
  static const int conversationsPageSize = 50;

  /// Debounce delay (ms) for the search field.
  static const int searchDebounceMs = 300;
}