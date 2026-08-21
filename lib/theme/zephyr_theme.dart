/// Zephyr application-wide dark theme definition.
///
/// Centralises every colour, gradient, typography, and component theme
/// so the entire app shares a single, consistent visual language.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Colour palette ────────────────────────────────────────────────────

/// Semantic colour tokens used throughout the Zephyr UI.
class ZephyrColors {
  ZephyrColors._();

  // ── Backgrounds ────────────────────────────────────────────────────

  /// Deepest background — used for scaffold roots.
  static const Color bgPrimary = Color(0xFF0A0A0F);

  /// Elevated surface — cards, sheets, dialogs.
  static const Color bgSecondary = Color(0xFF12121A);

  /// Raised surface — elevated cards, input fields.
  static const Color bgTertiary = Color(0xFF1A1A2E);

  /// Subtle divider / border colour.
  static const Color divider = Color(0xFF2A2A3E);

  // ── Accents ────────────────────────────────────────────────────────

  /// Primary brand accent — purple.
  static const Color accentPurple = Color(0xFF7C3AED);

  /// Secondary brand accent — blue.
  static const Color accentBlue = Color(0xFF3B82F6);

  // ── Semantic colours ───────────────────────────────────────────────

  /// Success / positive feedback.
  static const Color success = Color(0xFF10B981);

  /// Warning / caution.
  static const Color warning = Color(0xFFF59E0B);

  /// Error / destructive.
  static const Color error = Color(0xFFEF4444);

  // ── Text colours ───────────────────────────────────────────────────

  /// Primary text on dark backgrounds.
  static const Color textPrimary = Color(0xFFEEF0F6);

  /// Secondary / caption text.
  static const Color textSecondary = Color(0xFF9CA3AF);

  /// Muted / placeholder text.
  static const Color textMuted = Color(0xFF6B7280);

  // ── Gradient colours ───────────────────────────────────────────────

  /// Start colour of the primary gradient (purple).
  static const Color gradientStart = Color(0xFF7C3AED);

  /// End colour of the primary gradient (blue).
  static const Color gradientEnd = Color(0xFF3B82F6);

  /// Lighter variant of the purple accent for subtle highlights.
  static const Color accentPurpleLight = Color(0xFFA78BFA);

  /// Lighter variant of the blue accent.
  static const Color accentBlueLight = Color(0xFF93C5FD);
}

// ── Gradient helpers ──────────────────────────────────────────────────

/// The primary brand gradient flowing from purple to blue.
const LinearGradient zephyrPrimaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    ZephyrColors.gradientStart,
    ZephyrColors.gradientEnd,
  ],
);

/// A subtle shimmer gradient used for loading skeletons.
const LinearGradient zephyrShimmerGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFF1A1A2E),
    Color(0xFF2A2A3E),
    Color(0xFF1A1A2E),
  ],
);

// ── Typography ────────────────────────────────────────────────────────

/// Text theme using Google Fonts:
///
/// * **Space Grotesk** — headings and display text
/// * **Inter** — body copy, labels, and captions
class ZephyrTextTheme {
  ZephyrTextTheme._();

  static TextTheme build(TextTheme base) {
    final body = GoogleFonts.interTextTheme(base);
    final heading = GoogleFonts.spaceGroteskTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return body.copyWith(
      displayLarge: heading.displayLarge,
      displayMedium: heading.displayMedium,
      displaySmall: heading.displaySmall,
      headlineLarge: heading.headlineLarge,
      headlineMedium: heading.headlineMedium,
      headlineSmall: heading.headlineSmall,
      titleLarge: heading.titleLarge,
      titleMedium: heading.titleMedium,
      titleSmall: heading.titleSmall,
    );
  }
}

// ── Theme entry point ─────────────────────────────────────────────────

/// The single source of truth for Zephyr's [ThemeData].
///
/// Call [darkTheme] from [MaterialApp] to apply the full dark theme.
class ZephyrTheme {
  ZephyrTheme._();

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = ZephyrTextTheme.build(base.textTheme!);

    return base.copyWith(
      // ── Colours ────────────────────────────────────────────────────
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: ZephyrColors.accentPurple,
        onPrimary: Colors.white,
        secondary: ZephyrColors.accentBlue,
        onSecondary: Colors.white,
        surface: ZephyrColors.bgSecondary,
        onSurface: ZephyrColors.textPrimary,
        error: ZephyrColors.error,
        onError: Colors.white,
        tertiary: ZephyrColors.accentPurpleLight,
        onTertiary: Colors.white,
      ),

      // ── Surfaces ───────────────────────────────────────────────────
      scaffoldBackgroundColor: ZephyrColors.bgPrimary,
      canvasColor: ZephyrColors.bgPrimary,
      hintColor: ZephyrColors.textMuted,

      // ── Typography ─────────────────────────────────────────────────
      textTheme: textTheme.copyWith(
        bodyLarge: textTheme.bodyLarge!
            .copyWith(color: ZephyrColors.textPrimary),
        bodyMedium: textTheme.bodyMedium!
            .copyWith(color: ZephyrColors.textPrimary),
        bodySmall: textTheme.bodySmall!
            .copyWith(color: ZephyrColors.textSecondary),
        labelLarge: textTheme.labelLarge!
            .copyWith(color: ZephyrColors.textPrimary),
        labelMedium: textTheme.labelMedium!
            .copyWith(color: ZephyrColors.textSecondary),
        labelSmall: textTheme.labelSmall!
            .copyWith(color: ZephyrColors.textMuted),
        titleLarge: textTheme.titleLarge!
            .copyWith(color: ZephyrColors.textPrimary),
        titleMedium: textTheme.titleMedium!
            .copyWith(color: ZephyrColors.textPrimary),
        titleSmall: textTheme.titleSmall!
            .copyWith(color: ZephyrColors.textSecondary),
      ),

      // ── Divider ────────────────────────────────────────────────────
      dividerColor: ZephyrColors.divider,
      dividerTheme: const DividerThemeData(
        color: ZephyrColors.divider,
        space: 1,
        thickness: 1,
      ),

      // ── Input decoration ───────────────────────────────────────────
      inputDecorationTheme: _inputDecorationTheme,

      // ── Card ───────────────────────────────────────────────────────
      cardTheme: _cardTheme,

      // ── App bar ────────────────────────────────────────────────────
      appBarTheme: _appBarTheme,

      // ── Buttons ────────────────────────────────────────────────────
      elevatedButtonTheme: _elevatedButtonTheme,
      textButtonTheme: _textButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      iconButtonTheme: _iconButtonTheme,

      // ── Bottom sheet ───────────────────────────────────────────────
      bottomSheetTheme: _bottomSheetTheme,

      // ── Dialog ─────────────────────────────────────────────────────
      dialogTheme: _dialogTheme,

      // ── Navigation bar ─────────────────────────────────────────────
      navigationBarTheme: _navigationBarTheme,

      // ── Floating action button ─────────────────────────────────────
      floatingActionButtonTheme: _fabTheme,

      // ── List tile ──────────────────────────────────────────────────
      listTileTheme: _listTileTheme,

      // ── Chip ───────────────────────────────────────────────────────
      chipTheme: _chipTheme,

      // ── Switch / checkbox / radio ──────────────────────────────────
      switchTheme: _switchThemeData,
      checkboxTheme: _checkboxThemeData,
      radioTheme: _radioThemeData,

      // ── Slider ─────────────────────────────────────────────────────
      sliderTheme: _sliderThemeData,

      // ── Progress indicator ─────────────────────────────────────────
      progressIndicatorTheme: _progressIndicatorTheme,

      // ── Tooltip ────────────────────────────────────────────────────
      tooltipTheme: _tooltipTheme,

      // ── Banner ─────────────────────────────────────────────────────
      bannerTheme: _bannerTheme,
    );
  }

  // ── InputDecorationTheme ────────────────────────────────────────────

  static const InputDecorationTheme _inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: ZephyrColors.bgTertiary,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: ZephyrColors.divider, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: ZephyrColors.divider, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: ZephyrColors.accentPurple, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: ZephyrColors.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: ZephyrColors.error, width: 1.5),
    ),
    hintStyle: TextStyle(
      color: ZephyrColors.textMuted,
      fontSize: 14,
    ),
    labelStyle: TextStyle(
      color: ZephyrColors.textSecondary,
      fontSize: 14,
    ),
    prefixIconColor: ZephyrColors.textMuted,
    suffixIconColor: ZephyrColors.textMuted,
  );

  // ── CardTheme ───────────────────────────────────────────────────────

  static const CardTheme _cardTheme = CardTheme(
    color: ZephyrColors.bgSecondary,
    elevation: 2,
    shadowColor: Color(0x40000000),
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      side: BorderSide(color: ZephyrColors.divider, width: 0.5),
    ),
    clipBehavior: Clip.antiAlias,
  );

  // ── AppBarTheme ─────────────────────────────────────────────────────

  static const AppBarTheme _appBarTheme = AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: ZephyrColors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(
      color: ZephyrColors.textSecondary,
      size: 24,
    ),
    actionsIconTheme: IconThemeData(
      color: ZephyrColors.textSecondary,
      size: 24,
    ),
    scrolledUnderElevation: 1,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // ── ElevatedButtonTheme (gradient buttons) ──────────────────────────

  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      foregroundColor: Colors.white,
      backgroundColor: ZephyrColors.accentPurple,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  // ── TextButtonTheme ─────────────────────────────────────────────────

  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: ZephyrColors.accentPurpleLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  // ── OutlinedButtonTheme ─────────────────────────────────────────────

  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ZephyrColors.textPrimary,
      side: const BorderSide(color: ZephyrColors.divider, width: 1),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  // ── IconButtonTheme ─────────────────────────────────────────────────

  static const IconButtonThemeData _iconButtonTheme = IconButtonThemeData(
    style: ButtonStyle(
      iconColor: WidgetStatePropertyAll(ZephyrColors.textSecondary),
      foregroundColor: WidgetStatePropertyAll(ZephyrColors.textSecondary),
    ),
  );

  // ── BottomSheetTheme ────────────────────────────────────────────────

  static const BottomSheetThemeData _bottomSheetTheme = BottomSheetThemeData(
    backgroundColor: ZephyrColors.bgSecondary,
    surfaceTintColor: Colors.transparent,
    modalBackgroundColor: ZephyrColors.bgSecondary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    elevation: 4,
    clipBehavior: Clip.antiAlias,
  );

  // ── DialogTheme ─────────────────────────────────────────────────────

  static const DialogTheme _dialogTheme = DialogTheme(
    backgroundColor: ZephyrColors.bgSecondary,
    surfaceTintColor: Colors.transparent,
    elevation: 6,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
    titleTextStyle: TextStyle(
      color: ZephyrColors.textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    contentTextStyle: TextStyle(
      color: ZephyrColors.textSecondary,
      fontSize: 14,
    ),
    actionsPadding: EdgeInsets.only(bottom: 8),
  );

  // ── NavigationBarTheme ──────────────────────────────────────────────

  static const NavigationBarThemeData _navigationBarTheme =
      NavigationBarThemeData(
    backgroundColor: ZephyrColors.bgSecondary,
    indicatorColor: Color(0x307C3AED),
    elevation: 8,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    height: 64,
    surfaceTintColor: Colors.transparent,
    shadowColor: Color(0x40000000),
    iconTheme: WidgetStatePropertyAll(
      IconThemeData(
        color: ZephyrColors.textMuted,
        size: 24,
      ),
    ),
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(
        color: ZephyrColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  // ── FloatingActionButtonTheme ───────────────────────────────────────

  static const FloatingActionButtonThemeData _fabTheme =
      FloatingActionButtonThemeData(
    backgroundColor: ZephyrColors.accentPurple,
    foregroundColor: Colors.white,
    elevation: 6,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  );

  // ── ListTileTheme ───────────────────────────────────────────────────

  static const ListTileThemeData _listTileTheme = ListTileThemeData(
    iconColor: ZephyrColors.textMuted,
    textColor: ZephyrColors.textPrimary,
    subtitleTextStyle: TextStyle(
      color: ZephyrColors.textSecondary,
      fontSize: 13,
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    dense: true,
  );

  // ── ChipTheme ───────────────────────────────────────────────────────

  static const ChipThemeData _chipTheme = ChipThemeData(
    backgroundColor: ZephyrColors.bgTertiary,
    deleteIconColor: ZephyrColors.textMuted,
    labelStyle: TextStyle(
      color: ZephyrColors.textPrimary,
      fontSize: 13,
    ),
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  );

  // ── SwitchThemeData ─────────────────────────────────────────────────

  static const SwitchThemeData _switchThemeData = SwitchThemeData(
    thumbColor: WidgetStatePropertyAll(ZephyrColors.accentPurple),
    trackColor: WidgetStatePropertyAll(ZephyrColors.bgTertiary),
    trackOutlineColor: WidgetStatePropertyAll(ZephyrColors.divider),
  );

  // ── CheckboxThemeData ───────────────────────────────────────────────

  static const CheckboxThemeData _checkboxThemeData = CheckboxThemeData(
    checkColor: WidgetStatePropertyAll(Colors.white),
    fillColor: WidgetStatePropertyAll(ZephyrColors.accentPurple),
    side: BorderSide(color: ZephyrColors.divider, width: 1.5),
  );

  // ── RadioThemeData ──────────────────────────────────────────────────

  static const RadioThemeData _radioThemeData = RadioThemeData(
    fillColor: WidgetStatePropertyAll(ZephyrColors.accentPurple),
  );

  // ── SliderThemeData ─────────────────────────────────────────────────

  static const SliderThemeData _sliderThemeData = SliderThemeData(
    activeTrackColor: ZephyrColors.accentPurple,
    inactiveTrackColor: ZephyrColors.bgTertiary,
    thumbColor: ZephyrColors.accentPurple,
    overlayColor: Color(0x307C3AED),
  );

  // ── ProgressIndicatorThemeData ──────────────────────────────────────

  static const ProgressIndicatorThemeData _progressIndicatorTheme =
      ProgressIndicatorThemeData(
    color: ZephyrColors.accentPurple,
    linearTrackColor: ZephyrColors.bgTertiary,
    circularTrackColor: ZephyrColors.bgTertiary,
  );

  // ── TooltipThemeData ────────────────────────────────────────────────

  static const TooltipThemeData _tooltipTheme = TooltipThemeData(
    decoration: BoxDecoration(
      color: ZephyrColors.bgTertiary,
      borderRadius: BorderRadius.all(Radius.circular(6)),
    ),
    textStyle: TextStyle(
      color: ZephyrColors.textSecondary,
      fontSize: 12,
    ),
    waitDuration: Duration(milliseconds: 400),
  );

  // ── BannerThemeData ─────────────────────────────────────────────────

  static const BannerThemeData _bannerTheme = BannerThemeData(
    backgroundColor: Color(0xFF1A1520),
    textStyle: TextStyle(
      color: ZephyrColors.warning,
      fontSize: 13,
    ),
    contentPadding: EdgeInsets.all(12),
  );
}