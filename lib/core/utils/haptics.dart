import 'package:flutter/services.dart';

/// Centralized haptic feedback utilities.
class Haptics {
  Haptics._();

  /// Light tap — button press, chip select.
  static void light() => HapticFeedback.lightImpact();

  /// Medium tap — toggle, switch.
  static void medium() => HapticFeedback.mediumImpact();

  /// Heavy tap — delete, destructive action.
  static void heavy() => HapticFeedback.heavyImpact();

  /// Selection changed — dropdown, slider.
  static void selection() => HapticFeedback.selectionClick();

  /// Success action.
  static void success() {
    HapticFeedback.mediumImpact();
  }

  /// Error / warning.
  static void error() {
    HapticFeedback.heavyImpact();
  }
}
