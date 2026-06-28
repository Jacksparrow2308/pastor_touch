import 'package:flutter/material.dart';

class PastorColors {
  static const ink = Color(0xFF172033);
  static const muted = Color(0xFF64748B);
  static const cream = Color(0xFFF5F8FF);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFD8E2F3);
  static const teal = Color(0xFF1D4ED8);
  static const tealSoft = Color(0xFFEAF1FF);
  static const gold = Color(0xFFF59E0B);
  static const amber = gold;
  static const coral = Color(0xFFE76F51);
  static const green = Color(0xFF2E7D59);
  static const red = Color(0xFFC2413D);
}

class PastorTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: PastorColors.teal,
      brightness: Brightness.light,
      primary: PastorColors.teal,
      secondary: PastorColors.gold,
      tertiary: PastorColors.coral,
      surface: PastorColors.surface,
      error: PastorColors.red,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: PastorColors.cream,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: PastorColors.teal,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: PastorColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: PastorColors.line),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        titleTextStyle: TextStyle(
          color: PastorColors.ink,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: TextStyle(
          color: PastorColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: PastorColors.teal,
        unselectedLabelColor: PastorColors.muted,
        indicatorColor: PastorColors.gold,
        labelStyle: TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: PastorColors.surface,
        selectedItemColor: PastorColors.teal,
        unselectedItemColor: PastorColors.muted,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PastorColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PastorColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PastorColors.teal, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: PastorColors.teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PastorColors.teal,
          side: const BorderSide(color: PastorColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: PastorColors.teal,
        backgroundColor: PastorColors.tealSoft,
        secondarySelectedColor: PastorColors.teal,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(
        color: PastorColors.line,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PastorColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class PastorSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PastorSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5F8FF), Color(0xFFEFF6FF)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
