/// Service that captures the current screen / app context for use by
/// the AI overlay.
///
/// On Android this leverages the accessibility framework to determine
/// the foreground app, its package name, and the most recent
/// accessibility event. On other platforms it falls back to a best-
/// effort heuristic.
///
/// Listeners subscribe via [listenToChanges] and receive a plain-text
/// description every time the context changes.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../utils/logger.dart';

final _logger = Logger('Zephyr.ScreenContext');

// ── Platform channel ──────────────────────────────────────────────────

/// Method channel used to talk to the native accessibility bridge.
const _channel = MethodChannel('zephyr/screen_context');

// ── State holder ──────────────────────────────────────────────────────

/// Snapshot of the current screen context.
class ScreenContextSnapshot {
  /// The human-readable name of the foreground app (e.g. "Chrome").
  final String appName;

  /// The platform package identifier (e.g. "com.android.chrome").
  final String packageName;

  /// A short description of the current screen content derived from
  /// the last accessibility event. May be empty.
  final String screenDescription;

  /// When this snapshot was captured.
  final DateTime timestamp;

  const ScreenContextSnapshot({
    required this.appName,
    required this.packageName,
    required this.screenDescription,
    required this.timestamp,
  });

  /// Returns a single-line summary suitable for inclusion in a prompt.
  String toSummary() {
    final parts = <String>[
      'App: $appName ($packageName)',
      if (screenDescription.isNotEmpty) 'Screen: $screenDescription',
    ];
    return parts.join(' | ');
  }

  @override
  String toString() => toSummary();
}

// ── Service ───────────────────────────────────────────────────────────

/// Captures and streams screen-context updates.
///
/// Create a single instance and keep it alive for the lifetime of the
/// overlay. Call [dispose] when done.
class ScreenContextService {
  ScreenContextService._() : _snapshot = ScreenContextSnapshot(
        appName: 'Unknown',
        packageName: 'unknown',
        screenDescription: '',
        timestamp: DateTime.now(),
      );

  factory ScreenContextService() => _instance;
  static final ScreenContextService _instance = ScreenContextService._();

  /// The most recent context snapshot.
  ScreenContextSnapshot _snapshot;

  /// Broadcast stream that emits a new summary string every time the
  /// context changes.
  final _contextController = StreamController<String>.broadcast();

  /// Internal periodic timer that polls the native side for updates.
  Timer? _pollTimer;

  /// Whether the service has been started.
  bool _isListening = false;

  // ── Public accessors ────────────────────────────────────────────────

  /// Returns the latest context snapshot.
  ScreenContextSnapshot getCurrentContext() => _snapshot;

  /// Returns the latest context as a human-readable summary string.
  String getCurrentContextSummary() => _snapshot.toSummary();

  /// Subscribes to context-change events.
  ///
  /// Returns a [Stream] that yields a plain-text summary every time
  /// the foreground app or screen content changes.
  Stream<String> listenToChanges() => _contextController.stream;

  // ── Lifecycle ───────────────────────────────────────────────────────

  /// Starts listening for screen-context changes.
  ///
  /// On Android this registers a native listener and begins a periodic
  /// poll as a fallback. On other platforms only the poll runs.
  Future<void> start() async {
    if (_isListening) {
      _logger.warning('ScreenContextService already listening');
      return;
    }

    _isListening = true;
    _logger.info('Starting screen context listener');

    // Attempt to register a native listener.
    await _registerNativeListener();

    // Start a periodic poll as a fallback / supplement.
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  /// Stops listening and releases resources.
  void dispose() {
    _logger.info('Disposing ScreenContextService');
    _isListening = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _unregisterNativeListener();
    _contextController.close();
  }

  // ── Native bridge ───────────────────────────────────────────────────

  Future<void> _registerNativeListener() async {
    try {
      // Set up a method-call handler so the native side can push updates.
      _channel.setMethodCallHandler(_handleMethodCall);

      // Ask the native side to start sending events.
      await _channel.invokeMethod('startListening');
      _logger.fine('Native screen-context listener registered');
    } on PlatformException catch (e) {
      _logger.warning('Could not register native listener: ${e.message}');
    }
  }

  void _unregisterNativeListener() {
    try {
      _channel.invokeMethod('stopListening');
      _channel.setMethodCallHandler(null);
    } catch (_) {
      // Ignore — we're tearing down.
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onContextChanged':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        _onNativeUpdate(
          appName: args['appName'] as String? ?? 'Unknown',
          packageName: args['packageName'] as String? ?? 'unknown',
          screenDescription: args['screenDescription'] as String? ?? '',
        );
        break;
      default:
        _logger.warning('Unknown method call from native: ${call.method}');
    }
  }

  // ── Polling fallback ────────────────────────────────────────────────

  Future<void> _poll() async {
    try {
      final result =
          await _channel.invokeMethod<Map<String, dynamic>>('getCurrentContext');

      if (result != null) {
        _onNativeUpdate(
          appName: result['appName'] as String? ?? 'Unknown',
          packageName: result['packageName'] as String? ?? 'unknown',
          screenDescription: result['screenDescription'] as String? ?? '',
        );
      }
    } on PlatformException catch (e) {
      // Expected on platforms without the native plugin.
      _logger.fine('Poll failed (expected on non-Android): ${e.message}');
    }
  }

  // ── State mutation ──────────────────────────────────────────────────

  void _onNativeUpdate({
    required String appName,
    required String packageName,
    required String screenDescription,
  }) {
    final now = DateTime.now();
    final newSnapshot = ScreenContextSnapshot(
      appName: appName,
      packageName: packageName,
      screenDescription: screenDescription,
      timestamp: now,
    );

    // Only notify listeners if something actually changed.
    if (_snapshot.appName != newSnapshot.appName ||
        _snapshot.packageName != newSnapshot.packageName ||
        _snapshot.screenDescription != newSnapshot.screenDescription) {
      _snapshot = newSnapshot;
      _logger.fine('Context updated: $newSnapshot');

      // Emit only if there are active listeners.
      if (!_contextController.isClosed) {
        _contextController.add(newSnapshot.toSummary());
      }
    }
  }
}