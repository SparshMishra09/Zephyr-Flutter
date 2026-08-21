/// Service that manages the floating "ghost bubble" overlay.
///
/// The ghost bubble is a small, draggable circular widget that floats
/// above all other app content. Tapping it expands a mini chat panel
/// where the user can interact with the AI assistant without leaving
/// their current screen.
///
/// State is managed via [ChangeNotifier] so UI widgets can react to
/// visibility and expansion changes. Bubble position is persisted
/// across app launches using [SharedPreferences].
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_alert_window/system_alert_window.dart';

import '../core/utils/logger.dart';

final _logger = Logger('Zephyr.GhostBubble');

// ── Preferences keys ──────────────────────────────────────────────────

const _prefBubbleX = 'ghost_bubble_x';
const _prefBubbleY = 'ghost_bubble_y';
const _prefBubbleVisible = 'ghost_bubble_visible';

// ── Bubble states ─────────────────────────────────────────────────────

/// Represents the current visual state of the ghost bubble overlay.
enum GhostBubbleState {
  /// The bubble is not visible at all.
  hidden,

  /// The bubble is visible as a small circle (default).
  minimized,

  /// The bubble has expanded into a mini chat panel.
  expanded,
}

// ── Service ───────────────────────────────────────────────────────────

/// Manages the lifecycle and state of the ghost bubble overlay.
///
/// Extend or mix-in this class if you need custom behaviour, but the
/// singleton factory is the recommended entry point.
class GhostBubbleService extends ChangeNotifier {
  GhostBubbleService._();

  factory GhostBubbleService() => _instance;
  static final GhostBubbleService _instance = GhostBubbleService._();

  // ── State ──────────────────────────────────────────────────────────

  GhostBubbleState _state = GhostBubbleState.hidden;
  GhostBubbleState get state => _state;

  /// Whether the bubble is currently visible (minimized or expanded).
  bool get isVisible => _state != GhostBubbleState.hidden;

  /// Whether the bubble is currently expanded.
  bool get isExpanded => _state == GhostBubbleState.expanded;

  /// Horizontal position of the bubble (persisted).
  double _bubbleX = 0.0;

  /// Vertical position of the bubble (persisted).
  double _bubbleY = 0.0;

  Offset get bubblePosition => Offset(_bubbleX, _bubbleY);

  /// Whether the system alert window permission has been granted.
  bool _permissionGranted = false;
  bool get permissionGranted => _permissionGranted;

  /// Stream controller for incoming chat messages from the overlay UI.
  final _messageController = StreamController<String>.broadcast();

  /// Stream of user messages sent from the ghost bubble chat panel.
  Stream<String> get messageStream => _messageController.stream;

  /// Whether the AI is currently generating a response.
  bool _isTyping = false;
  bool get isTyping => _isTyping;

  /// The current AI response text (accumulated during streaming).
  String _responseText = '';
  String get responseText => _responseText;

  // ── Lifecycle ───────────────────────────────────────────────────────

  /// Initialises the service: checks permissions and restores position.
  ///
  /// Call once during app startup (e.g. in [main]).
  Future<void> init() async {
    _logger.info('Initialising GhostBubbleService');

    // Check system alert window permission.
    _permissionGranted = await SystemAlertWindow.hasPermission;

    if (!_permissionGranted) {
      _logger.warning('System alert window permission not granted');
    }

    // Restore persisted position.
    await _loadPosition();

    notifyListeners();
  }

  /// Checks the current permission status.
  Future<bool> checkPermission() async {
    _permissionGranted = await SystemAlertWindow.hasPermission;
    notifyListeners();
    return _permissionGranted;
  }

  /// Requests the system alert window permission from the user.
  ///
  /// Returns whether the permission was granted.
  Future<bool> requestPermission() async {
    _logger.info('Requesting system alert window permission');
    final granted = await SystemAlertWindow.alertWindowHandler;
    _permissionGranted = granted;
    notifyListeners();
    return granted;
  }

  // ── Visibility control ──────────────────────────────────────────────

  /// Shows the ghost bubble in its minimized state.
  Future<void> show() async {
    if (_state != GhostBubbleState.hidden) return;

    if (!_permissionGranted) {
      _permissionGranted = await SystemAlertWindow.hasPermission;
      if (!_permissionGranted) {
        _logger.warning('Cannot show bubble: permission not granted');
        notifyListeners();
        return;
      }
    }

    _state = GhostBubbleState.minimized;
    _logger.info('Ghost bubble shown at (${_bubbleX}, ${_bubbleY})');
    notifyListeners();
  }

  /// Hides the ghost bubble.
  void hide() {
    if (_state == GhostBubbleState.hidden) return;

    _state = GhostBubbleState.hidden;
    _isTyping = false;
    _responseText = '';
    _logger.info('Ghost bubble hidden');
    notifyListeners();
  }

  /// Toggles between visible and hidden states.
  void toggle() {
    if (isVisible) {
      hide();
    } else {
      show();
    }
  }

  /// Toggles between minimized and expanded states (no-op when hidden).
  void toggleExpansion() {
    if (_state == GhostBubbleState.hidden) return;

    if (_state == GhostBubbleState.expanded) {
      _state = GhostBubbleState.minimized;
    } else {
      _state = GhostBubbleState.expanded;
    }

    _logger.fine('Bubble expansion toggled: $_state');
    notifyListeners();
  }

  // ── Position management ─────────────────────────────────────────────

  /// Updates the bubble position and persists it.
  void updatePosition(double x, double y) {
    _bubbleX = x;
    _bubbleY = y;
    _savePosition();
    notifyListeners();
  }

  /// Saves the current position to [SharedPreferences].
  Future<void> _savePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefBubbleX, _bubbleX);
      await prefs.setDouble(_prefBubbleY, _bubbleY);
    } catch (e) {
      _logger.warning('Failed to save bubble position: $e');
    }
  }

  /// Loads the persisted position from [SharedPreferences].
  Future<void> _loadPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _bubbleX = prefs.getDouble(_prefBubbleX) ?? 0.0;
      _bubbleY = prefs.getDouble(_prefBubbleY) ?? 0.0;

      // If no position was saved, default to the right edge.
      if (_bubbleX == 0.0 && _bubbleY == 0.0) {
        final width = ui.window.physicalSize.width / ui.window.devicePixelRatio;
        _bubbleX = width - 60;
        _bubbleY = 200;
      }
    } catch (e) {
      _logger.warning('Failed to load bubble position: $e');
    }
  }

  // ── Chat integration ────────────────────────────────────────────────

  /// Sends a message from the ghost bubble chat panel.
  ///
  /// This emits the message on [messageStream] for any listener
  /// (e.g. the chat view-model) to handle.
  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _messageController.add(text.trim());
  }

  /// Marks the AI as currently typing.
  void setTyping(bool typing) {
    _isTyping = typing;
    if (typing) {
      _responseText = '';
    }
    notifyListeners();
  }

  /// Appends a chunk to the current AI response.
  void appendResponseChunk(String chunk) {
    _responseText += chunk;
    notifyListeners();
  }

  /// Clears the current response text.
  void clearResponse() {
    _responseText = '';
    _isTyping = false;
    notifyListeners();
  }

  // ── Cleanup ─────────────────────────────────────────────────────────

  @override
  void dispose() {
    _logger.info('Disposing GhostBubbleService');
    _messageController.close();
    super.dispose();
  }
}