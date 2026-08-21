/// The floating ghost bubble widget for the Zephyr overlay.
///
/// A draggable, animated circular bubble that expands into a mini chat
/// panel when tapped. Features a dark glass-morphism aesthetic and
/// integrates with [GhostBubbleService] for state management.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:system_alert_window/system_alert_window.dart';

import 'ghost_bubble_service.dart';

// ── Constants ─────────────────────────────────────────────────────────

/// Diameter of the minimised bubble.
const _bubbleSize = 56.0;

/// Diameter of the bubble during drag (slightly larger for affordance).
const _bubbleDragSize = 64.0;

/// Width of the expanded chat panel.
const _panelWidth = 320.0;

/// Height of the expanded chat panel.
const _panelHeight = 420.0;

/// Radius of the panel corners.
const _panelCornerRadius = 20.0;

/// Duration for expand / collapse animations.
const _animDuration = Duration(milliseconds: 300);

/// Curve for expand / collapse animations.
const _animCurve = Curves.easeOutCubic;

// ── Root overlay widget ───────────────────────────────────────────────

/// Entry-point widget that should be passed to
/// [SystemAlertWindow.startSystemAlertWindow].
///
/// Wraps the [GhostBubbleWidget] in a [MaterialApp] so that navigation
/// and theming work correctly inside the overlay.
class GhostBubbleOverlayApp extends StatelessWidget {
  const GhostBubbleOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const _OverlayRoot(),
    );
  }
}

/// Lays the bubble out in an overlay window using [Stack].
class _OverlayRoot extends StatelessWidget {
  const _OverlayRoot();

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (_) {},
      child: Stack(
        children: [
          // Transparent background to capture gestures outside the bubble.
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                // Tapping outside the panel collapses it.
                if (GhostBubbleService().isExpanded) {
                  GhostBubbleService().toggleExpansion();
                }
              },
              behavior: HitTestBehavior.translucent,
            ),
          ),

          // The actual bubble.
          const GhostBubbleWidget(),
        ],
      ),
    );
  }
}

// ── Main bubble widget ────────────────────────────────────────────────

/// A draggable, animated floating bubble that expands into a mini chat
/// panel when tapped.
///
/// Observes [GhostBubbleService] for state changes and reflects them
/// in the UI.
class GhostBubbleWidget extends StatefulWidget {
  const GhostBubbleWidget({super.key});

  @override
  State<GhostBubbleWidget> createState() => _GhostBubbleWidgetState();
}

class _GhostBubbleWidgetState extends State<GhostBubbleWidget>
    with SingleTickerProviderStateMixin {
  final _service = GhostBubbleService();

  /// Animation controller for expand / collapse.
  late final AnimationController _expandController;

  /// Animated scale value (0.0 → 1.0).
  late final Animation<double> _expandAnimation;

  /// Whether the bubble is currently being dragged.
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: _animDuration,
      reverseDuration: _animDuration,
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: _animCurve,
    );

    // Sync animation with service state.
    _service.addListener(_onServiceChanged);

    // Initialise animation value from current state.
    if (_service.isExpanded) {
      _expandController.value = 1.0;
    } else {
      _expandController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _expandController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;

    if (_service.state == GhostBubbleState.hidden) {
      // Bubble is hidden — do nothing visually.
      return;
    }

    if (_service.isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  void _onTapBubble() {
    if (_service.state == GhostBubbleState.hidden) {
      _service.show();
    } else {
      _service.toggleExpansion();
    }
  }

  void _onDismiss() {
    _service.hide();
  }

  @override
  Widget build(BuildContext context) {
    if (_service.state == GhostBubbleState.hidden) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _service.bubblePosition.dx,
      top: _service.bubblePosition.dy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Expanded panel ──────────────────────────────────────────
          AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _expandAnimation.value,
                child: Transform.scale(
                  scale: 0.95 + (0.05 * _expandAnimation.value),
                  alignment: Alignment.topLeft,
                  child: child,
                ),
              );
            },
            child: _buildChatPanel(),
          ),

          // ── Draggable bubble ────────────────────────────────────────
          GestureDetector(
            onTap: _onTapBubble,
            onPanUpdate: (details) {
              setState(() {
                _isDragging = details.velocity.pixelsPerSecond.distance > 50;
              });
              _service.updatePosition(
                _service.bubblePosition.dx + details.delta.dx,
                _service.bubblePosition.dy + details.delta.dy,
              );
            },
            onPanEnd: (_) {
              setState(() => _isDragging = false);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isDragging ? _bubbleDragSize : _bubbleSize,
              height: _isDragging ? _bubbleDragSize : _bubbleSize,
              decoration: _bubbleDecoration,
              child: const _BubbleIcon(),
            ),
          ),
        ],
      ),
    );
  }

  /// Decoration for the circular bubble.
  BoxDecoration get _bubbleDecoration => BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xDD1A1A2E),
        border: Border.all(
          color: const Color(0x807B61FF),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x607B61FF),
            blurRadius: 16,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      );

  /// Builds the expanded chat panel.
  Widget _buildChatPanel() {
    return Positioned(
      left: 0,
      top: _bubbleSize + 12,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_panelCornerRadius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: _panelWidth,
              height: _panelHeight,
              decoration: BoxDecoration(
                color: const Color(0xE612122A),
                borderRadius: BorderRadius.circular(_panelCornerRadius),
                border: Border.all(
                  color: const Color(0x407B61FF),
                  width: 1,
                ),
              ),
              child: const _ChatPanelContent(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bubble icon ───────────────────────────────────────────────────────

/// The icon shown inside the minimised bubble.
class _BubbleIcon extends StatelessWidget {
  const _BubbleIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing ring behind the icon.
        Positioned.fill(
          child: CustomPaint(
            painter: _PulseRingPainter(),
          ),
        ),
        // Zephyr lightning bolt icon.
        Icon(
          Icons.bolt_rounded,
          color: const Color(0xFFA78BFA),
          size: 28,
        ),
      ],
    );
  }
}

/// Painter for the subtle pulsing ring behind the bubble icon.
class _PulseRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0x307B61FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Chat panel content ────────────────────────────────────────────────

/// The interior of the expanded chat panel: messages area, typing
/// indicator, and input field.
class _ChatPanelContent extends StatefulWidget {
  const _ChatPanelContent();

  @override
  State<_ChatPanelContent> createState() => _ChatPanelContentState();
}

class _ChatPanelContentState extends State<_ChatPanelContent> {
  final _service = GhostBubbleService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _service.sendMessage(text);
    _textController.clear();

    // Scroll to bottom after a short delay (allows the UI to update).
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onSubmitted(String text) {
    _onSend();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ────────────────────────────────────────────────────
        _buildHeader(),

        // ── Messages area ─────────────────────────────────────────────
        Expanded(
          child: _buildMessagesArea(),
        ),

        // ── Typing indicator ──────────────────────────────────────────
        if (_service.isTyping) const _TypingIndicator(),

        // ── Input field ───────────────────────────────────────────────
        _buildInputField(),
      ],
    );
  }

  /// Header bar with title and dismiss button.
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x207B61FF), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bolt_rounded,
            color: Color(0xFFA78BFA),
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'Zephyr AI',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          // Minimize button.
          IconButton(
            icon: const Icon(Icons.minimize, color: Colors.white70, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _service.toggleExpansion(),
            tooltip: 'Minimize',
          ),
          const SizedBox(width: 4),
          // Close button.
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _service.hide(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  /// Scrollable area showing the AI response.
  Widget _buildMessagesArea() {
    return ValueListenableBuilder<SharedPreferences?>(
      valueListenable: const _PrefsNotifier(),
      builder: (context, _, child) => child!,
      child: _buildMessagesScroll(),
    );
  }

  Widget _buildMessagesScroll() {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        return SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message when no response yet.
              if (!_service.isTyping && _service.responseText.isEmpty)
                _buildWelcomeMessage(),

              // AI response.
              if (_service.responseText.isNotEmpty)
                _buildAIMessage(_service.responseText),
            ],
          ),
        );
      },
    );
  }

  /// Welcome / placeholder message.
  Widget _buildWelcomeMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1A7B61FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How can I help?',
            style: TextStyle(
              color: Color(0xFFA78BFA),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Ask me anything about what you see on screen.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Renders an AI response bubble.
  Widget _buildAIMessage(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0x207B61FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x307B61FF), width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  /// Input bar at the bottom of the panel.
  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0x207B61FF), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Ask Zephyr…',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: const Color(0x1AFFFFFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                isDense: true,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
              maxLines: 1,
              onSubmitted: _onSubmitted,
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          // Send button.
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7B61FF), Color(0xFF9F7AFF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x407B61FF),
                  blurRadius: 8,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _onSend,
              tooltip: 'Send',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────

/// Animated dots indicator shown while the AI is generating a response.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.bolt_rounded,
            color: Color(0xFFA78BFA),
            size: 14,
          ),
          const SizedBox(width: 8),
          const Text(
            'Zephyr is thinking',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          // Animated dots.
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                spacing: 3,
                children: List.generate(3, (index) {
                  final delay = index * 0.15;
                  final value = ((_controller.value + delay) % 1.0);
                  final opacity = value < 0.5 ? value * 2 : (1 - value) * 2;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        Colors.white24,
                        const Color(0xFFA78BFA),
                        opacity,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────

/// Minimal ValueListenable that always notifies — used to trigger
/// rebuilds when SharedPreferences is first loaded.
class _PrefsNotifier extends ValueListenable<SharedPreferences?> {
  const _PrefsNotifier();

  @override
  SharedPreferences? get value => null;

  @override
  void addListener(ValueChanged<SharedPreferences?> listener) {}

  @override
  void removeListener(ValueChanged<SharedPreferences?> listener) {}

  @override
  int get valueId => 0;
}