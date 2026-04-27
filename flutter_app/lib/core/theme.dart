import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Brand palette ────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1B5E20);       // deep forest green
  static const Color primaryLight = Color(0xFF2E7D32);  // medium green
  static const Color primaryContainer = Color(0xFFC8E6C9);
  static const Color secondary = Color(0xFFE65100);     // deep orange
  static const Color secondaryContainer = Color(0xFFFFE0B2);
  static const Color error = Color(0xFFC62828);
  static const Color bgLight = Color(0xFFF8F9FA);
  static const Color bgDark = Color(0xFF0F0F0F);
  static const Color surface = Colors.white;
  static const Color cardShadow = Color(0x14000000);

  // ── Ocean palette ─────────────────────────────────────────────────────────
  static const Color oceanPrimary = Color(0xFF01579B);       // deep ocean blue
  static const Color oceanPrimaryLight = Color(0xFF0277BD);  // medium blue
  static const Color oceanPrimaryContainer = Color(0xFFB3E5FC);
  static const Color oceanSecondary = Color(0xFF00838F);     // teal
  static const Color oceanBg = Color(0xFFE1F5FE);

  static const _textTheme = TextTheme(
    displayLarge: TextStyle(
        fontFamily: 'Roboto', fontWeight: FontWeight.w700, letterSpacing: -0.5),
    headlineLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
    headlineMedium: TextStyle(fontWeight: FontWeight.w700),
    headlineSmall: TextStyle(fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(height: 1.5),
    bodyMedium: TextStyle(height: 1.4),
    bodySmall: TextStyle(height: 1.4),
    labelLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
  );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          secondary: secondary,
          error: error,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: primaryContainer,
          secondary: secondary,
          onSecondary: Colors.white,
          secondaryContainer: secondaryContainer,
          error: error,
        ),
        scaffoldBackgroundColor: bgLight,
        textTheme: _textTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primary, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(color: Color(0xFF6B6B6B)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            textStyle: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: const BorderSide(color: primary, width: 1.5),
            textStyle: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primary),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 8,
          shadowColor: Colors.black26,
          indicatorColor: primaryContainer,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEEEEEE),
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          secondary: secondary,
          error: error,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: bgDark,
        textTheme: _textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF121212),
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Color(0xFF2A2A2A), width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF3A3A3A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF3A3A3A)),
          ),
          filled: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryLight,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Color(0xFF78DC77),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      );

  static ThemeData get oceanTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: oceanPrimary,
          secondary: oceanSecondary,
          error: error,
          brightness: Brightness.light,
        ).copyWith(
          primary: oceanPrimary,
          onPrimary: Colors.white,
          primaryContainer: oceanPrimaryContainer,
          secondary: oceanSecondary,
          onSecondary: Colors.white,
          error: error,
        ),
        scaffoldBackgroundColor: oceanBg,
        textTheme: _textTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: oceanPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Color(0xFFB3E5FC), width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFFB3E5FC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFFB3E5FC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: oceanPrimary, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(color: Color(0xFF546E7A)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: oceanPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            textStyle: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: oceanPrimary,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: const BorderSide(color: oceanPrimary, width: 1.5),
            textStyle: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: oceanPrimary),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: oceanPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 8,
          shadowColor: Colors.black26,
          indicatorColor: oceanPrimaryContainer,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE1F5FE),
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
}

/// The three user-selectable app themes.
enum AppThemeChoice { white, dark, ocean }

extension AppThemeChoiceX on AppThemeChoice {
  String get label {
    switch (this) {
      case AppThemeChoice.white:
        return 'White';
      case AppThemeChoice.dark:
        return 'Dark';
      case AppThemeChoice.ocean:
        return 'Ocean';
    }
  }
}

