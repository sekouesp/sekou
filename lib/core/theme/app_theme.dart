import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// App-wide color constants — no more per-department colors.
class AppColors {
  AppColors._();

  // ── Brand Colors ──────────────────────────────────────────────
  static const Color blue = Color(0xFF007ACC);
  static const Color brown = Color(0xFF7A4B1D);
  static const Color blueDark = Color(0xFF005F9E);
  static const Color brownLight = Color(0xFFA66B35);

  // ── Semantic Colors ───────────────────────────────────────────
  static const Color success = Color(0xFF059669);
  static const Color error = Color(0xFFE11D48);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0891B2);

  // ── Light Theme Colors ────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightBackgroundAlt = Color(0xFFF5F7FF);
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightOnBackground = Color(0xFF0F172A);
  static const Color lightOnSurface = Color(0xFF1E293B);
  static const Color lightOnSurfaceVariant = Color(0xFF64748B);
  static const Color lightOutline = Color(0xFFE2E8F0);

  // ── Dark Theme Colors ─────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkOnBackground = Color(0xFFF8FAFC);
  static const Color darkOnSurface = Color(0xFFF1F5F9);
  static const Color darkOnSurfaceVariant = Color(0xFF94A3B8);
  static const Color darkOutline = Color(0xFF334155);

  // ── Chat Colors ──────────────────────────────────────────────
  static const Color chatBubbleReceived = Color(0xFFF1F3FF);
}

/// Light Theme
 ThemeData get lightTheme {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    brightness: Brightness.light,
    primary: AppColors.blue,
    secondary: AppColors.brown,
    error: AppColors.error,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightOnSurface,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.lightBackground,
    visualDensity: VisualDensity.adaptivePlatformDensity,

    // ── AppBar Theme ──────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w900,
        fontSize: 18,
        color: AppColors.lightOnBackground,
      ),
      iconTheme: IconThemeData(color: AppColors.lightOnSurface),
    ),

    // ── Card Theme ────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.lightOutline),
      ),
      margin: const EdgeInsets.only(bottom: 8),
    ),

    // ── Bottom Sheet Theme ────────────────────────────────────
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.lightOutline,
    ),

    // ── Dialog Theme ──────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w900,
        fontSize: 18,
        color: AppColors.lightOnBackground,
      ),
    ),

    // ── Navigation Bar ────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withOpacity(0.85),
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.blue.withOpacity(0.12),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'Inter',
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 11,
          color: isSelected ? AppColors.blue : AppColors.lightOnSurfaceVariant,
        );
      }),
    ),

    // ── Input Decoration ──────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.lightOutline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.lightOutline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.blue, width: 2),
      ),
      hintStyle: TextStyle(
        color: AppColors.lightOnSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    ),

    // ── Elevated Button ───────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    ),

    // ── Filled Button ─────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    ),

    // ── Outlined Button ───────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue,
        side: const BorderSide(color: AppColors.blue),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    ),

    // ── Chip Theme ────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightSurfaceVariant,
      selectedColor: AppColors.blue,
      side: BorderSide(color: AppColors.lightOutline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    // ── SnackBar ──────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.lightOnBackground,
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),

    // ── Divider ───────────────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: AppColors.lightOutline,
      thickness: 1,
      space: 1,
    ),

    // ── Popup Menu ────────────────────────────────────────────
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
    ),

    // ── Page Transitions ──────────────────────────────────────
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: const PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Dark Theme
ThemeData get darkTheme {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    brightness: Brightness.dark,
    primary: AppColors.blue,
    secondary: AppColors.brownLight,
    error: AppColors.error,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkOnSurface,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.darkBackground,
    visualDensity: VisualDensity.adaptivePlatformDensity,

    // ── AppBar Theme ──────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w900,
        fontSize: 18,
        color: AppColors.darkOnBackground,
      ),
      iconTheme: IconThemeData(color: AppColors.darkOnSurface),
    ),

    // ── Card Theme ────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.darkOutline),
      ),
      margin: const EdgeInsets.only(bottom: 8),
    ),

    // ── Bottom Sheet Theme ────────────────────────────────────
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.darkOutline,
    ),

    // ── Dialog Theme ──────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w900,
        fontSize: 18,
        color: AppColors.darkOnBackground,
      ),
    ),

    // ── Navigation Bar ────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkSurface.withOpacity(0.85),
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.blue.withOpacity(0.2),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'Inter',
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 11,
          color: isSelected ? AppColors.blue : AppColors.darkOnSurfaceVariant,
        );
      }),
    ),

    // ── Input Decoration ──────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.darkOutline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.darkOutline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.blue, width: 2),
      ),
      hintStyle: TextStyle(
        color: AppColors.darkOnSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    ),

    // ── Elevated Button ───────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    ),

    // ── Filled Button ─────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    ),

    // ── Outlined Button ───────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue,
        side: const BorderSide(color: AppColors.blue),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    ),

    // ── Chip Theme ────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkSurfaceVariant,
      selectedColor: AppColors.blue,
      side: BorderSide(color: AppColors.darkOutline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    // ── SnackBar ──────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkOnBackground,
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        color: AppColors.darkBackground,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),

    // ── Divider ───────────────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: AppColors.darkOutline,
      thickness: 1,
      space: 1,
    ),

    // ── Popup Menu ────────────────────────────────────────────
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
    ),

    // ── Page Transitions ──────────────────────────────────────
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: const PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
