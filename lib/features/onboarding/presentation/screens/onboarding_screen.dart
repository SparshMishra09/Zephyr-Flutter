/// The Onboarding screen for Zephyr.
///
/// A full-screen page view with 3 onboarding pages explaining the app's
/// core features. Includes page indicators, smooth transitions, and
/// navigation buttons (Next / Get Started / Skip).
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/app_constants.dart';
import '../../../../theme/zephyr_theme.dart';
import '../viewmodels/onboarding_viewmodel.dart';
import '../widgets/onboarding_page.dart';

/// Full-screen onboarding experience shown on first launch.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Moves to the next page or completes onboarding if on the last page.
  void _nextPage() {
    final vm = context.read<OnboardingViewModel>();
    if (vm.isLastPage) {
      _completeOnboarding();
    } else {
      vm.nextPage();
      _animateToPage(vm.currentPage);
    }
  }

  /// Completes the onboarding flow and navigates to the home screen.
  Future<void> _completeOnboarding() async {
    await context.read<OnboardingViewModel>().complete();
  }

  /// Skips the onboarding flow entirely.
  Future<void> _skipOnboarding() async {
    await context.read<OnboardingViewModel>().skip();
  }

  /// Smoothly animates to the target page.
  void _animateToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: UIConstants.animationMedium,
      curve: Curves.easeInOutCubic,
    );
  }

  /// Jumps directly to a page (used by page indicator dots).
  void _goToPage(int page) {
    context.read<OnboardingViewModel>().goToPage(page);
    _pageController.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZephyrColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button (top-right) ──────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(UIConstants.spacingMd),
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: const Text('Skip'),
                ).animate(
                  effects: const [
                    FadeEffect(
                      duration: Duration(milliseconds: 500),
                      delay: Duration(milliseconds: 300),
                    ),
                  ],
                ),
              ),
            ),

            // ── Page View ────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  context.read<OnboardingViewModel>().goToPage(page);
                },
                children: const [
                  // Page 1: Your AI Research Assistant
                  _OnboardingPageOne(),
                  // Page 2: Import Your Documents
                  _OnboardingPageTwo(),
                  // Page 3: Always Available
                  _OnboardingPageThree(),
                ],
              ),
            ),

            // ── Bottom section: indicators + CTA ────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UIConstants.spacingXl,
                vertical: UIConstants.spacingLg,
              ),
              child: Column(
                children: [
                  // Page indicator dots.
                  Consumer<OnboardingViewModel>(
                    builder: (context, vm, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        OnboardingViewModel.totalPages,
                        (index) => _buildDot(index, vm.currentPage),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // CTA button.
                  Consumer<OnboardingViewModel>(
                    builder: (context, vm, _) {
                      final isLast = vm.isLastPage;
                      return SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ZephyrColors.accentPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                UIConstants.radiusMd,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            isLast ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single page indicator dot.
  Widget _buildDot(int index, int currentPage) {
    final isActive = index == currentPage;
    return AnimatedContainer(
      duration: UIConstants.animationMedium,
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? ZephyrColors.accentPurple
            : ZephyrColors.bgTertiary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _goToPage(index),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

// ── Page 1: Your AI Research Assistant ─────────────────────────────

class _OnboardingPageOne extends StatelessWidget {
  const _OnboardingPageOne();

  @override
  Widget build(BuildContext context) {
    return const OnboardingPage(
      illustrationBuilder: (size) => _IllustrationOne(size),
      title: 'Your AI Research\nAssistant',
      description:
          'Zephyr brings the power of AI to your documents. Ask questions, '
          'get summaries, and discover insights — all powered by '
          'retrieval-augmented generation right on your device.',
    );
  }
}

class _IllustrationOne extends StatelessWidget {
  final double size;
  const _IllustrationOne(this.size);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow circle.
        Container(
          width: size * 0.8,
          height: size * 0.8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                ZephyrColors.accentPurple.withOpacity(0.3),
                ZephyrColors.accentPurple.withOpacity(0.05),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Middle ring.
        Container(
          width: size * 0.55,
          height: size * 0.55,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ZephyrColors.accentPurple.withOpacity(0.4),
                ZephyrColors.accentBlue.withOpacity(0.3),
              ],
            ),
            border: Border.all(
              color: ZephyrColors.accentPurple.withOpacity(0.2),
              width: 1.5,
            ),
          ),
        ),
        // Center icon.
        Container(
          width: size * 0.3,
          height: size * 0.3,
          decoration: BoxDecoration(
            gradient: zephyrPrimaryGradient,
            borderRadius: BorderRadius.circular(size * 0.08),
            boxShadow: [
              BoxShadow(
                color: ZephyrColors.accentPurple.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
        // Floating accent dots.
        Positioned(
          top: size * 0.12,
          right: size * 0.18,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: ZephyrColors.accentBlue.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: size * 0.15,
          left: size * 0.15,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: ZephyrColors.accentPurpleLight.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Page 2: Import Your Documents ──────────────────────────────────

class _OnboardingPageTwo extends StatelessWidget {
  const _OnboardingPageTwo();

  @override
  Widget build(BuildContext context) {
    return const OnboardingPage(
      illustrationBuilder: (size) => _IllustrationTwo(size),
      title: 'Import Your\nDocuments',
      description:
          'Add PDFs, documents, spreadsheets, and more. Zephyr chunks and '
          'indexes your files so you can search and query them with natural '
          'language — no setup required.',
    );
  }
}

class _IllustrationTwo extends StatelessWidget {
  final double size;
  const _IllustrationTwo(this.size);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow.
        Container(
          width: size * 0.8,
          height: size * 0.8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                ZephyrColors.accentBlue.withOpacity(0.25),
                ZephyrColors.accentBlue.withOpacity(0.05),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Upload arrow circle.
        Container(
          width: size * 0.5,
          height: size * 0.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ZephyrColors.accentBlue.withOpacity(0.3),
              width: 1.5,
            ),
          ),
        ),
        // Document stack (layered cards).
        Positioned(
          top: size * 0.2,
          child: Transform.translate(
            offset: const Offset(12, -8),
            child: _DocCard(
              width: size * 0.22,
              height: size * 0.28,
              color: ZephyrColors.bgTertiary,
              icon: Icons.picture_as_pdf_rounded,
              iconColor: ZephyrColors.error,
            ),
          ),
        ),
        Positioned(
          top: size * 0.22,
          child: Transform.translate(
            offset: const Offset(-8, -4),
            child: _DocCard(
              width: size * 0.22,
              height: size * 0.28,
              color: ZephyrColors.bgTertiary,
              icon: Icons.description_rounded,
              iconColor: ZephyrColors.accentBlue,
            ),
          ),
        ),
        // Front card.
        _DocCard(
          width: size * 0.24,
          height: size * 0.3,
          color: ZephyrColors.bgSecondary,
          icon: Icons.upload_file_rounded,
          iconColor: ZephyrColors.accentPurpleLight,
          isFront: true,
        ),
        // Floating accent dots.
        Positioned(
          top: size * 0.08,
          left: size * 0.2,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: ZephyrColors.accentPurple.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: size * 0.12,
          right: size * 0.18,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: ZephyrColors.accentBlue.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _DocCard extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final bool isFront;

  const _DocCard({
    required this.width,
    required this.height,
    required this.color,
    required this.icon,
    required this.iconColor,
    this.isFront = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFront
              ? ZephyrColors.accentPurple.withOpacity(0.4)
              : ZephyrColors.divider,
          width: isFront ? 1.5 : 0.5,
        ),
        boxShadow: isFront
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(icon, color: iconColor, size: width * 0.4),
      ),
    );
  }
}

// ── Page 3: Always Available ───────────────────────────────────────

class _OnboardingPageThree extends StatelessWidget {
  const _OnboardingPageThree();

  @override
  Widget build(BuildContext context) {
    return const OnboardingPage(
      illustrationBuilder: (size) => _IllustrationThree(size),
      title: 'Always\nAvailable',
      description:
          'The ghost bubble follows you across apps. Tap it anytime to ask '
          'a question, summarize content, or search your documents — no '
          'context switching needed.',
    );
  }
}

class _IllustrationThree extends StatelessWidget {
  final double size;
  const _IllustrationThree(this.size);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow.
        Container(
          width: size * 0.8,
          height: size * 0.8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                ZephyrColors.accentPurple.withOpacity(0.2),
                ZephyrColors.accentPurple.withOpacity(0.05),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Phone mockup.
        Container(
          width: size * 0.35,
          height: size * 0.55,
          decoration: BoxDecoration(
            color: ZephyrColors.bgSecondary,
            borderRadius: BorderRadius.circular(size * 0.06),
            border: Border.all(
              color: ZephyrColors.divider,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Screen content lines.
              Padding(
                padding: EdgeInsets.all(size * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: size * 0.12,
                      height: size * 0.02,
                      decoration: BoxDecoration(
                        color: ZephyrColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: size * 0.02,
                      decoration: BoxDecoration(
                        color: ZephyrColors.bgTertiary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: size * 0.2,
                      height: size * 0.02,
                      decoration: BoxDecoration(
                        color: ZephyrColors.bgTertiary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Chat bubbles.
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: size * 0.2,
                        height: size * 0.06,
                        decoration: BoxDecoration(
                          color: ZephyrColors.accentPurple.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: size * 0.22,
                        height: size * 0.08,
                        decoration: BoxDecoration(
                          color: ZephyrColors.bgTertiary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Ghost bubble overlay.
              Positioned(
                right: -size * 0.04,
                top: size * 0.15,
                child: Container(
                  width: size * 0.12,
                  height: size * 0.12,
                  decoration: BoxDecoration(
                    gradient: zephyrPrimaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ZephyrColors.accentPurple.withOpacity(0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Floating accent dots.
        Positioned(
          top: size * 0.1,
          left: size * 0.15,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: ZephyrColors.accentPurpleLight.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: size * 0.1,
          right: size * 0.15,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: ZephyrColors.accentBlue.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}