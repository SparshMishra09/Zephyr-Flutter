/// Application-wide configuration constants.
///
/// Provides centralized access to app metadata, API keys, embedding
/// parameters, and database settings. Sensitive values (e.g. API keys)
/// should be injected at runtime via `.env` or a settings screen.
library;

class AppConfig {
  const AppConfig._();

  // ── App identity ────────────────────────────────────────────────────

  /// Display name shown in the UI and on the app icon.
  static const String appName = 'Zephyr';

  /// Semantic version of the current build.
  static const String appVersion = '1.0.0';

  // ── Gemini API ──────────────────────────────────────────────────────

  /// Google Gemini API key.
  ///
  /// Leave empty in source; set at runtime via a `.env` file or the
  /// in-app settings screen.
  static const String geminiApiKey = '';

  // ── Embedding & chunking defaults ───────────────────────────────────

  /// Default dimensionality for text embeddings (e.g. text-embedding-3-small).
  static const int defaultEmbeddingDim = 384;

  /// Maximum number of chunks to generate per document.
  static const int maxChunks = 500;

  /// Target number of characters per text chunk.
  static const int chunkSize = 500;

  /// Number of overlapping characters between consecutive chunks.
  static const int chunkOverlap = 50;

  // ── Retrieval ───────────────────────────────────────────────────────

  /// Default number of nearest neighbours to return for vector search.
  static const int topK = 5;

  // ── Database ────────────────────────────────────────────────────────

  /// File path for the local Hive database.
  static const String databasePath = 'zephyr.db';
}