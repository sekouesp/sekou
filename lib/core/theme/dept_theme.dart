import 'package:flutter/material.dart';

class DeptTheme {
  final Color seed;
  final String dept;

  const DeptTheme({required this.seed, required this.dept});

  ColorScheme get scheme => ColorScheme.fromSeed(seedColor: seed);

  Color get primary => scheme.primary;
  Color get primaryContainer => scheme.primaryContainer;
  Color get onPrimaryContainer => scheme.onPrimaryContainer;

  /// Fond de page exact par département (fidèle au web)
  Color get pageBg {
    switch (dept) {
      case 'Génie Informatique': return const Color(0xFFF5F7FF);
      case 'Génie Civil':        return const Color(0xFFFFFCF0);
      case 'Génie Électrique':   return const Color(0xFFF0FCFD);
      case 'Génie Mécanique':    return const Color(0xFFF8FAFC);
      case 'Génie Chimique et Biologie Appliquée': return const Color(0xFFF0FDF4);
      case 'Gestion':            return const Color(0xFFFFF1F2);
      default:                   return const Color(0xFFF8FBFF);
    }
  }

  /// Teinte légère pour les cards/chips
  Color get tinted => Color.alphaBlend(seed.withOpacity(0.08), Colors.white);

  /// Couleur de surface légère
  Color get surface => Color.alphaBlend(seed.withOpacity(0.04), Colors.white);

  static DeptTheme of(String? dept) {
    switch (dept) {
      case 'Génie Informatique':
        return const DeptTheme(seed: Color(0xFF4F46E5), dept: 'Génie Informatique');
      case 'Génie Civil':
        return const DeptTheme(seed: Color(0xFFD97706), dept: 'Génie Civil');
      case 'Génie Électrique':
        return const DeptTheme(seed: Color(0xFF0891B2), dept: 'Génie Électrique');
      case 'Génie Mécanique':
        return const DeptTheme(seed: Color(0xFF475569), dept: 'Génie Mécanique');
      case 'Génie Chimique et Biologie Appliquée':
        return const DeptTheme(seed: Color(0xFF059669), dept: 'Génie Chimique et Biologie Appliquée');
      case 'Gestion':
        return const DeptTheme(seed: Color(0xFFE11D48), dept: 'Gestion');
      default:
        return const DeptTheme(seed: Color(0xFF4F46E5), dept: '');
    }
  }
}
