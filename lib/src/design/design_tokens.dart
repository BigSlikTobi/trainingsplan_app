import 'package:flutter/material.dart';

abstract final class AppTokens {
  static const appName = 'T4L Trainer';
}

abstract final class AppAssets {
  static const brandIcon = 'assets/brand/t4l_trainer_icon.png';
  static const brandWordmark = 'assets/brand/t4l_trainer_wordmark.png';
}

abstract final class AppColors {
  static const ink = Color(0xFF18201B);
  static const paper = Color(0xFFEEECEA);
  static const bg = Color(0xFF0F1210);
  static const surface = Color(0xFF181C1A);
  static const surface2 = Color(0xFF1F2421);
  static const surface3 = Color(0xFF252A27);
  static const sage = Color(0xFF6E8A73);
  static const coral = Color(0xFFCB6B52);
  static const gold = Color(0xFFC9A256);
  static const error = Color(0xFFBA1A1A);
  static const white = Colors.white;
  static const transparent = Colors.transparent;
}

abstract final class AppBorder {
  static final thin = AppColors.paper.withValues(alpha: 0.06);
  static final medium = AppColors.paper.withValues(alpha: 0.10);
}

abstract final class AppRadii {
  static const xsmall = 6.0;
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const pill = 999.0;
}

/// A small, consistent type scale. Prefer these over inline `fontSize:` literals
/// so text sizing stays coherent and is easy to tune in one place.
abstract final class AppType {
  static const caption = 11.0;
  static const footnote = 12.0;
  static const body = 14.0;
  static const callout = 15.0;
  static const headline = 17.0;
  static const title = 20.0;
  static const largeTitle = 24.0;
  static const display = 28.0;
}

/// Standard motion durations. Keeping these aligned gives the UI a coherent
/// rhythm and makes it easy to honour reduced-motion preferences in one place.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);
}

abstract final class AppSpacing {
  static const xxsmall = 4.0;
  static const xsmall = 6.0;
  static const small = 8.0;
  static const medium = 10.0;
  static const large = 12.0;
  static const xlarge = 14.0;
  static const page = 16.0;
  static const hero = 18.0;
  static const emptyState = 24.0;
}

abstract final class AppOpacity {
  static const hairline = .06;
  static const subtle = .08;
  static const wash = .09;
  static const tint = .13;
  static const selectedFill = .22;
  static const borderTint = .26;
  static const mutedIcon = .62;
  static const mutedText = .68;
  static const inverseMuted = .70;
  static const inverseBody = .78;
}
