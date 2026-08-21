/// ViewModel for the Settings screen.
///
/// Manages application settings persisted via [SharedPreferences],
/// including API configuration, feature toggles, RAG parameters, and
/// data management actions.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys used to store settings in [SharedPreferences].
class _SettingsKeys {
  _SettingsKeys._();

  static const String geminiApiKey = 'gemini_api_key';
  static const String enableGhostBubble = 'enable_ghost_bubble';
  static const String enableDarkMode = 'enable_dark_mode';
  static const String enableAccessibility = 'enable_accessibility';
  static const String enableBackgroundIndexing = 'enable_background_indexing';
  static const String chunkSize = 'chunk_size';
  static const String topK = 'top_k';
  static const String similarityThreshold = 'similarity_threshold';
}

/// Reactive view model for the Zephyr settings screen.
///
/// Reads and writes settings to [SharedPreferences] and notifies
/// listeners when any value changes.
class SettingsViewModel extends ChangeNotifier {
  final SharedPreferences _prefs;

  SettingsViewModel(this._prefs);

  // ── API Configuration ────────────────────────────────────────────

  String _geminiApiKey = '';
  String get geminiApiKey => _geminiApiKey;

  bool _isApiKeySet => _geminiApiKey.trim().isNotEmpty;
  bool get isApiKeySet => _isApiKeySet;

  /// Masked version of the API key for display (shows first 4 and last 4 chars).
  String get maskedApiKey {
    if (_geminiApiKey.length < 10) return '••••••••';
    return '${_geminiApiKey.substring(0, 4)}••••••••${_geminiApiKey.substring(_geminiApiKey.length - 4)}';
  }

  // ── Feature Toggles ──────────────────────────────────────────────

  bool _enableGhostBubble = true;
  bool get enableGhostBubble => _enableGhostBubble;

  /// Dark mode is always enabled in Zephyr.
  bool get enableDarkMode => true;

  bool _enableAccessibility = false;
  bool get enableAccessibility => _enableAccessibility;

  bool _enableBackgroundIndexing = true;
  bool get enableBackgroundIndexing => _enableBackgroundIndexing;

  // ── RAG Settings ─────────────────────────────────────────────────

  int _chunkSize = 512;
  int get chunkSize => _chunkSize;

  int _topK = 5;
  int get topK => _topK;

  double _similarityThreshold = 0.75;
  double get similarityThreshold => _similarityThreshold;

  // ── Lifecycle ────────────────────────────────────────────────────

  /// Initialises the view model by loading persisted settings.
  void init() {
    _geminiApiKey = _prefs.getString(_SettingsKeys.geminiApiKey) ?? '';
    _enableGhostBubble = _prefs.getBool(_SettingsKeys.enableGhostBubble) ?? true;
    _enableAccessibility =
        _prefs.getBool(_SettingsKeys.enableAccessibility) ?? false;
    _enableBackgroundIndexing =
        _prefs.getBool(_SettingsKeys.enableBackgroundIndexing) ?? true;
    _chunkSize = _prefs.getInt(_SettingsKeys.chunkSize) ?? 512;
    _topK = _prefs.getInt(_SettingsKeys.topK) ?? 5;
    _similarityThreshold =
        _prefs.getDouble(_SettingsKeys.similarityThreshold) ?? 0.75;

    notifyListeners();
  }

  // ── API Configuration ────────────────────────────────────────────

  /// Saves the Gemini API key to persistent storage.
  Future<void> saveApiKey(String key) async {
    _geminiApiKey = key.trim();
    await _prefs.setString(_SettingsKeys.geminiApiKey, _geminiApiKey);
    notifyListeners();
  }

  /// Clears the stored API key.
  Future<void> clearApiKey() async {
    _geminiApiKey = '';
    await _prefs.remove(_SettingsKeys.geminiApiKey);
    notifyListeners();
  }

  // ── Feature Toggles ──────────────────────────────────────────────

  /// Toggles the ghost bubble overlay feature.
  Future<void> toggleGhostBubble() async {
    _enableGhostBubble = !_enableGhostBubble;
    await _prefs.setBool(_SettingsKeys.enableGhostBubble, _enableGhostBubble);
    notifyListeners();
  }

  /// Toggles accessibility features (larger text, high contrast).
  Future<void> toggleAccessibility() async {
    _enableAccessibility = !_enableAccessibility;
    await _prefs.setBool(
      _SettingsKeys.enableAccessibility,
      _enableAccessibility,
    );
    notifyListeners();
  }

  /// Toggles background document indexing.
  Future<void> toggleBackgroundIndexing() async {
    _enableBackgroundIndexing = !_enableBackgroundIndexing;
    await _prefs.setBool(
      _SettingsKeys.enableBackgroundIndexing,
      _enableBackgroundIndexing,
    );
    notifyListeners();
  }

  // ── RAG Settings ─────────────────────────────────────────────────

  /// Updates the chunk size for document processing (256 – 2048).
  Future<void> updateChunkSize(int size) async {
    _chunkSize = size.clamp(256, 2048);
    await _prefs.setInt(_SettingsKeys.chunkSize, _chunkSize);
    notifyListeners();
  }

  /// Updates the top-K retrieval count (1 – 20).
  Future<void> updateTopK(int k) async {
    _topK = k.clamp(1, 20);
    await _prefs.setInt(_SettingsKeys.topK, _topK);
    notifyListeners();
  }

  /// Updates the similarity threshold (0.0 – 1.0).
  Future<void> updateSimilarityThreshold(double threshold) async {
    _similarityThreshold = threshold.clamp(0.0, 1.0);
    await _prefs.setDouble(
      _SettingsKeys.similarityThreshold,
      _similarityThreshold,
    );
    notifyListeners();
  }

  // ── Data Management ──────────────────────────────────────────────

  /// Exports all settings to a JSON file and returns the file path.
  Future<String?> exportData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/zephyr_export_$timestamp.json';

      final data = {
        'exportedAt': DateTime.now().toIso8601String(),
        'version': '1.0.0',
        'settings': {
          'enableGhostBubble': _enableGhostBubble,
          'enableAccessibility': _enableAccessibility,
          'enableBackgroundIndexing': _enableBackgroundIndexing,
          'chunkSize': _chunkSize,
          'topK': _topK,
          'similarityThreshold': _similarityThreshold,
        },
      };

      final file = File(filePath);
      await file.writeAsString(jsonEncode(data));

      return filePath;
    } catch (e) {
      debugPrint('Export failed: $e');
      return null;
    }
  }

  /// Clears all user data and settings from SharedPreferences.
  Future<void> clearData() async {
    await _prefs.clear();
    // Reset to defaults.
    _geminiApiKey = '';
    _enableGhostBubble = true;
    _enableAccessibility = false;
    _enableBackgroundIndexing = true;
    _chunkSize = 512;
    _topK = 5;
    _similarityThreshold = 0.75;
    notifyListeners();
  }

  /// Resets all settings to their default values (preserves API key).
  Future<void> resetSettings() async {
    final savedApiKey = _geminiApiKey;

    _enableGhostBubble = true;
    _enableAccessibility = false;
    _enableBackgroundIndexing = true;
    _chunkSize = 512;
    _topK = 5;
    _similarityThreshold = 0.75;

    await _prefs.setBool(_SettingsKeys.enableGhostBubble, _enableGhostBubble);
    await _prefs.setBool(
      _SettingsKeys.enableAccessibility,
      _enableAccessibility,
    );
    await _prefs.setBool(
      _SettingsKeys.enableBackgroundIndexing,
      _enableBackgroundIndexing,
    );
    await _prefs.setInt(_SettingsKeys.chunkSize, _chunkSize);
    await _prefs.setInt(_SettingsKeys.topK, _topK);
    await _prefs.setDouble(
      _SettingsKeys.similarityThreshold,
      _similarityThreshold,
    );

    // Restore API key.
    _geminiApiKey = savedApiKey;
    if (savedApiKey.isNotEmpty) {
      await _prefs.setString(_SettingsKeys.geminiApiKey, savedApiKey);
    }

    notifyListeners();
  }
}