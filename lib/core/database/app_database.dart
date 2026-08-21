/// Hive-based database wrapper for Zephyr.
///
/// Provides typed access to four Hive boxes:
///
/// * [documentsBox]  — stored [Document] records
/// * [chunksBox]     — stored [TextChunk] records
/// * [conversationsBox] — stored [Conversation] records
/// * [messagesBox]   — stored [ChatMessage] records
///
/// Call [init] once during app startup and [close] on shutdown.
library;

import 'package:hive_flutter/hive_flutter.dart';

/// Typed adapters are registered by name so the box key type is inferred.
part 'app_database.g.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase _instance = AppDatabase._();
  factory AppDatabase() => _instance;

  // ── Boxes ───────────────────────────────────────────────────────────

  /// Box that stores indexed documents.
  late final Box<Map> _documentsBox;

  /// Box that stores text chunks with their embeddings.
  late final Box<Map> _chunksBox;

  /// Box that stores conversation metadata.
  late final Box<Map> _conversationsBox;

  /// Box that stores individual chat messages.
  late final Box<Map> _messagesBox;

  /// Whether the database has been initialised.
  bool get isOpen => _documentsBox.isOpen;

  // ── Public accessors ────────────────────────────────────────────────

  Box<Map> get documentsBox => _documentsBox;
  Box<Map> get chunksBox => _chunksBox;
  Box<Map> get conversationsBox => _conversationsBox;
  Box<Map> get messagesBox => _messagesBox;

  // ── Lifecycle ───────────────────────────────────────────────────────

  /// Initialises Hive and opens all four boxes.
  ///
  /// [path] is the directory where Hive stores its files.
  /// If omitted, the default application documents directory is used.
  Future<void> init({String? path}) async {
    if (isOpen) return;

    await Hive.initFlutter(path);

    _documentsBox = await Hive.openBox<Map>('documents');
    _chunksBox = await Hive.openBox<Map>('chunks');
    _conversationsBox = await Hive.openBox<Map>('conversations');
    _messagesBox = await Hive.openBox<Map>('messages');
  }

  /// Closes every box and disposes the Hive instance.
  Future<void> close() async {
    await _documentsBox.close();
    await _chunksBox.close();
    await _conversationsBox.close();
    await _messagesBox.close();
  }

  /// Deletes every key from all boxes — useful for a "reset app" action.
  Future<void> clearAll() async {
    await _documentsBox.clear();
    await _chunksBox.clear();
    await _conversationsBox.clear();
    await _messagesBox.clear();
  }
}