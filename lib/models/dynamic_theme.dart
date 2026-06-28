import 'package:flutter/material.dart';
import '../models/app_theme_model.dart';

// =============================================================================
//  ThemeExtension — carries the 3 new per-section colours into the widget tree
//  Usage:  Theme.of(context).appColors.commentBubble
// =============================================================================
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color commentBubble;
  final Color otherCommentBubble;
  final Color instructionBox;
  final Color homeworkBox;

  const AppColorsExtension({
    required this.commentBubble,
    required this.otherCommentBubble,
    required this.instructionBox,
    required this.homeworkBox,
  });

  @override
  AppColorsExtension copyWith({
    Color? commentBubble,
    Color? otherCommentBubble,
    Color? instructionBox,
    Color? homeworkBox,
  }) {
    return AppColorsExtension(
      commentBubble: commentBubble ?? this.commentBubble,
      otherCommentBubble: otherCommentBubble ?? this.otherCommentBubble,
      instructionBox: instructionBox ?? this.instructionBox,
      homeworkBox: homeworkBox ?? this.homeworkBox,
    );
  }

  @override
  AppColorsExtension lerp(AppColorsExtension? other, double t) {
    if (other == null) return this;
    return AppColorsExtension(
      commentBubble: Color.lerp(commentBubble, other.commentBubble, t)!,
      otherCommentBubble: Color.lerp(
        otherCommentBubble,
        other.otherCommentBubble,
        t,
      )!,
      instructionBox: Color.lerp(instructionBox, other.instructionBox, t)!,
      homeworkBox: Color.lerp(homeworkBox, other.homeworkBox, t)!,
    );
  }
}

// Convenience extension so you can write:
//   Theme.of(context).appColors.commentBubble
extension ThemeAppColors on ThemeData {
  AppColorsExtension get appColors =>
      extension<AppColorsExtension>() ??
      const AppColorsExtension(
        commentBubble: Color(0xFFFFD700),
        otherCommentBubble: Color(0xFF2A2A2A),
        instructionBox: Color(0xFFB8960C),
        homeworkBox: Color(0xFFFFA500),
      );
}

// =============================================================================
//  CENTRAL THEME BUILDER
// =============================================================================
/// 🎨 CENTRAL THEME BUILDER
/// Every widget style in the app is built from AppThemeColors here.
/// When a new theme is selected, this rebuilds and the whole app updates.
class DynamicTheme {
  static ThemeData build(AppThemeColors c, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onAccent,
      secondary: c.secondary,
      onSecondary: c.onAccent,
      error: c.danger,
      onError: c.inverseText,
      surface: c.surface,
      onSurface: c.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Roboto',
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: c.primary.withValues(alpha: 0.06),
      focusColor: c.primary.withValues(alpha: 0.10),

      // ── Carry the 3 new colours as a ThemeExtension ──────────────────────
      extensions: [
        AppColorsExtension(
          commentBubble: c.commentBubble,
          otherCommentBubble: c.otherCommentBubble,
          instructionBox: c.instructionBox,
          homeworkBox: c.homeworkBox,
        ),
      ],

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: c.background,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: c.primary),
      ),

      // ── Bottom Nav ────────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.primary,
        unselectedItemColor: c.mutedText,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.cardBorder.withOpacity(0.22)),
        ),
      ),

      // ── Input fields ──────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        labelStyle: TextStyle(color: c.mutedText),
        hintStyle: TextStyle(color: c.mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.primary.withOpacity(0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.primary, width: 1.4),
        ),
      ),

      // ── Elevated Button ───────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      // ── Text Button ───────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          overlayColor: c.primary.withValues(alpha: 0.10),
        ),
      ),

      // ── Outlined Button ───────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          side: BorderSide(color: c.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          overlayColor: c.primary.withValues(alpha: 0.10),
        ),
      ),

      // ── Icon Button ───────────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.primary,
          highlightColor: c.primary.withValues(alpha: 0.10),
          hoverColor: c.primary.withValues(alpha: 0.06),
          focusColor: c.primary.withValues(alpha: 0.10),
        ),
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.primary : c.mutedText,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.primary.withOpacity(0.28)
              : c.mutedText.withOpacity(0.18),
        ),
      ),

      // ── Checkbox ─────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(c.onAccent),
        side: BorderSide(color: c.mutedText),
      ),

      // ── Radio ─────────────────────────────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.primary : c.mutedText,
        ),
      ),

      // ── Slider ────────────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.mutedText.withOpacity(0.3),
        thumbColor: c.primary,
        overlayColor: c.primary.withOpacity(0.15),
        valueIndicatorColor: c.primary,
        valueIndicatorTextStyle: TextStyle(color: c.onAccent),
      ),

      // ── SnackBar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surface,
        contentTextStyle: TextStyle(color: c.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.primary.withOpacity(0.4)),
        ),
      ),

      // ── Dialog ───────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: c.mutedText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Bottom Sheet ──────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // ── Chip ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        labelStyle: TextStyle(
          color: c.text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: c.primary.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      // ── Tab Bar ───────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: c.primary,
        unselectedLabelColor: c.mutedText,
        indicatorColor: c.primary,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),

      // ── List Tile ─────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: c.text,
        iconColor: c.primary,
        subtitleTextStyle: TextStyle(color: c.mutedText, fontSize: 13),
      ),

      // ── Icon ─────────────────────────────────────────────────────────────
      iconTheme: IconThemeData(color: c.primary),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1),

      // ── Progress Indicator ────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),

      // ── Floating Action Button ────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onAccent,
        elevation: 2,
      ),

      // ── Text ─────────────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: c.text,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: c.text,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: c.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: c.text, fontSize: 16),
        bodyMedium: TextStyle(color: c.text, fontSize: 14),
        bodySmall: TextStyle(color: c.mutedText, fontSize: 12),
        labelSmall: TextStyle(color: c.mutedText, fontSize: 11),
      ),
    );
  }
}
