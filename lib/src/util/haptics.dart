import 'package:flutter/services.dart';

/// Semantic haptic feedback for key interactions.
///
/// Wrapping [HapticFeedback] in intent-named helpers keeps call sites readable
/// and gives the app a consistent tactile language. Every call is a no-op on
/// platforms without haptics (and in widget tests), so these are always safe to
/// invoke from UI callbacks.
abstract final class Haptics {
  /// A light tick for routine confirmations (logging a set, toggling a chip).
  static void selection() => HapticFeedback.selectionClick();

  /// A medium impact for starting a meaningful action (begin a workout).
  static void action() => HapticFeedback.mediumImpact();

  /// A stronger cue for completing something significant (finish a workout).
  static void success() => HapticFeedback.heavyImpact();

  /// A buzz for destructive or failed actions.
  static void warning() => HapticFeedback.vibrate();
}
