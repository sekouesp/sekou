import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Simplified theme — no more per-department colors.
/// All users see the same blue/brand colors.
class DeptTheme {
  final Color seed;
  final String dept;

  const DeptTheme({required this.seed, required this.dept});

  Color get primary => AppColors.blue;
  Color get primaryContainer => AppColors.blue.withOpacity(0.1);
  Color get onPrimaryContainer => AppColors.blue;

  /// Page background — same for all departments now.
  Color get pageBg => AppColors.lightBackground;

  /// Tinted surface.
  Color get tinted => AppColors.blue.withOpacity(0.06);

  /// Surface color.
  Color get surface => AppColors.lightSurface;

  /// Returns a constant DeptTheme regardless of department.
  static DeptTheme of(String? dept) {
    return const DeptTheme(seed: AppColors.blue, dept: '');
  }
}
