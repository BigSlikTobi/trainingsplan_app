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
  static const paper = Color(0xFFF2EFE6);
  static const bg = Color(0xFFF5F4F0);
  static const sage = Color(0xFF6E8A73);
  static const coral = Color(0xFFCB6B52);
  static const gold = Color(0xFFE8B35E);
  static const error = Color(0xFFBA1A1A);
  static const white = Colors.white;
  static const transparent = Colors.transparent;
}

abstract final class AppRadii {
  static const xsmall = 6.0;
  static const small = 8.0;
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
