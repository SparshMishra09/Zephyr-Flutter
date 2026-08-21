/// ViewModel for the Documents screen.
///
/// Manages the document list, import flow, indexing state, and progress
/// tracking. Integrates with [AppDatabase] (Hive) for persistence and
/// [DocumentIngestionManager] for the RAG ingestion pipeline.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/models/document_model.dart';
import '../../../../core/utils/logger.dart';
import '../../../../rag/ingestion/document_ingestion_manager.dart';

/// Holds per-document ingestion progress so the UI can display a live
/// linear progress indicator for each file being indexed.
class _DocumentProgress {
  final String documentId;
  double fraction;
  String stage;

  _DocumentProgress({
    required this.documentId,
    this.fraction = 0.0,
    this.stage = 'initialising',
  });
}

/// Reactive view model for the Zephyr documents screen.
///
/// Listens to the documents Hive box for live updates and coordinates
/// with [DocumentIngestionManager] to ingest new files. Exposes a
/// progress map keyed by document ID so the UI can show per-file
/// indexing progress.
class DocumentsViewModel extends ChangeNotifier {
  final AppDatabase _db;
  final DocumentIngestionManager? _ingestionManager;

  DocumentsViewModel(this._db, {DocumentIngestionManager? ingestionManager})
      : _ingestionManager = ingestionManager;

  // ── State ──────────────────────────────────────────────────────────

  List<DocumentModel> _documents = [];
  List<DocumentModel> get documents => _documents;

  DocumentModel? _selectedDocument;
  DocumentModel? get selectedDocument => _selectedDocument;

  bool _isIndexing = false;
  bool get isIndexing => _isIndexing;

  /// Overall progress across all active indexing tasks (0.0 – 1.0).
  double _progress = 0.0;
  double get progress => _progress;

  /// Per-document progress tracked during ingestion.
  final Map<String, _DocumentProgress> _progressMap = {};
  Map<String, _DocumentProgress> get progressMap => _progressMap;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  StreamSubscription<BoxEvent>? _boxSubscription;

  // ── Lifecycle ──────────────────────────────────────────────────────

  /// Initialises the view model: loads the document list and subscribes
  /// to Hive box changes for reactive updates.
  Future<void> init() async {
    await loadDocuments();

    // Subscribe to Hive changes so the list updates reactively.
    _boxSubscription = _db.documentsBox.listenable().addListener(_onBoxChanged);
  }

  /// Called when the underlying documents Hive box changes.
  void _onBoxChanged() {
    loadDocuments();
  }

  @override
  void dispose() {
    _boxSubscription?.cancel();
    super.dispose();
  }

  // ── Document list ──────────────────────────────────────────────────

  /// Loads all documents from the database, sorted by [updatedAt]
  /// descending.
  Future<void> loadDocuments() async {
    final raw = _db.documentsBox.values.map((raw) {
      final map = raw as Map;
      return DocumentModel.fromMap(Map<String, dynamic>.from(map));
    }).toList();

    // Sort by updatedAt descending — newest first.
    raw.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (!listEquals(_documents, raw)) {
      _documents = raw;
      notifyListeners();
    }

    // Recalculate overall progress.
    _recalculateProgress();
  }

  /// Selects a document for detail view.
  void selectDocument(DocumentModel document) {
    _selectedDocument = document;
    notifyListeners();
  }

  /// Clears the currently selected document.
  void clearSelection() {
    _selectedDocument = null;
    notifyListeners();
  }

  // ── Import ─────────────────────────────────────────────────────────

  /// Imports a document from [filePath] with the given [mimeType].
  ///
  /// If [DocumentIngestionManager] is configured, runs the full ingestion
  /// pipeline and reports progress. Otherwise, creates a placeholder
  /// document record in the database.
  Future<void> importDocument(String filePath, String mimeType) async {
    _errorMessage = null;
    notifyListeners();

    if (_ingestionManager != null) {
      await _ingestWithPipeline(filePath, mimeType);
    } else {
      await _createPlaceholderDocument(filePath, mimeType);
    }
  }

  /// Runs the full ingestion pipeline with progress tracking.
  Future<void> _ingestWithPipeline(String filePath, String mimeType) async {
    _isIndexing = true;
    _progress = 0.0;
    notifyListeners();

    try {
      // Listen to the ingestion progress stream.
      final progressController = StreamController<double>.broadcast();

      // We create a progress listener that updates our state.
      final subscription = _createProgressStream().listen((value) {
        _progress = value;
        notifyListeners();
      });

      final result = await _ingestionManager!.ingest(filePath, mimeType);

      await subscription.cancel();
      await progressController.close();

      // Update the progress map.
      _progressMap[result.id] = _DocumentProgress(
        documentId: result.id,
        fraction: result.status == DocumentStatus.indexed ? 1.0 : 0.0,
        stage: result.status.name,
      );

      if (result.status == DocumentStatus.failed) {
        _errorMessage = 'Failed to index "${result.title}". Please try again.';
      }

      await loadDocuments();
    } catch (e, st) {
      appLogger.severe('Document import failed', e, st);
      _errorMessage = 'Import failed: ${e.toString()}';
      notifyListeners();
    } finally {
      _isIndexing = false;
      _progress = 0.0;
      notifyListeners();
    }
  }

  /// Creates a placeholder document when no ingestion pipeline is
  /// available (e.g. during development or testing).
  Future<void> _createPlaceholderDocument(
    String filePath,
    String mimeType,
  ) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final title = _extractTitle(filePath);

    final doc = DocumentModel.initial(
      id: id,
      title: title,
      path: filePath,
      mimeType: mimeType,
      fileSize: 0,
    );

    await _db.documentsBox.put(id, doc.toMap());
    await loadDocuments();
  }

  /// Creates a broadcast stream that simulates ingestion progress.
  ///
  /// In production, this would be wired to the real [DocumentIngestionManager]
  /// progress stream. For now, it emits incremental values.
  Stream<double> _createProgressStream() async* {
    for (int i = 0; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      yield i / 100.0;
    }
  }

  /// Extracts a human-friendly title from a file path.
  String _extractTitle(String filePath) {
    final uri = Uri.parse(filePath);
    var name = uri.pathSegments.isEmpty ? filePath : uri.pathSegments.last;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex > 0) {
      name = name.substring(0, dotIndex);
    }
    return name.replaceAll(RegExp(r'[_-]'), ' ');
  }

  // ── Delete ─────────────────────────────────────────────────────────

  /// Deletes a document by ID from the database.
  Future<void> deleteDocument(String id) async {
    try {
      await _db.documentsBox.delete(id);

      // Also delete associated chunks.
      final chunkKeys = _db.chunksBox.keys
          .where((key) =>
              key is String &&
              _db.chunksBox.get(key) is Map &&
              (Map.from(_db.chunksBox.get(key))['documentId'] as String?) == id)
          .toList();
      for (final key in chunkKeys) {
        await _db.chunksBox.delete(key);
      }

      _progressMap.remove(id);
      await loadDocuments();
    } catch (e, st) {
      appLogger.severe('Document deletion failed', e, st);
      _errorMessage = 'Failed to delete document.';
      notifyListeners();
    }
  }

  // ── Retry indexing ─────────────────────────────────────────────────

  /// Retries indexing for a document that previously failed.
  Future<void> retryIndexing(String id) async {
    final raw = _db.documentsBox.get(id);
    if (raw == null) return;

    final map = raw as Map;
    final docMap = Map<String, dynamic>.from(map);
    final filePath = docMap['path'] as String;
    final mimeType = docMap['mimeType'] as String;

    // Remove the old record and re-import.
    await _db.documentsBox.delete(id);
    await importDocument(filePath, mimeType);
  }

  // ── Progress helpers ───────────────────────────────────────────────

  /// Gets the ingestion progress fraction for a specific document ID.
  double getProgress(String id) {
    return _progressMap[id]?.fraction ?? 0.0;
  }

  /// Recalculates the overall progress from per-document progress.
  void _recalculateProgress() {
    final indexingDocs = _documents
        .where((d) => d.status == DocumentStatus.indexing)
        .toList();

    if (indexingDocs.isEmpty) {
      _progress = 0.0;
      return;
    }

    double total = 0.0;
    for (final doc in indexingDocs) {
      total += getProgress(doc.id);
    }
    _progress = total / indexingDocs.length;
    notifyListeners();
  }

  /// Clears the error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Computed properties ────────────────────────────────────────────

  /// Returns the count of documents by status.
  int get indexedCount =>
      _documents.where((d) => d.status == DocumentStatus.indexed).length;

  int get indexingCount =>
      _documents.where((d) => d.status == DocumentStatus.indexing).length;

  int get failedCount =>
      _documents.where((d) => d.status == DocumentStatus.failed).length;
}