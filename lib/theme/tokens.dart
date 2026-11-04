import 'package:flutter/material.dart';

/// Colour tokens from design-system/myfschool/MASTER.md. Screens never use
/// raw Color(0x..) values; a dark palette can later swap these.
abstract final class AppColors {
  /// FPT orange: large surfaces, app bar, icons. Never small text on white.
  static const Color brand = Color(0xFFF37021);

  /// Text-sized orange and fills that carry white text (5.2:1).
  static const Color brandStrong = Color(0xFFC2410C);
  static const Color brandSoft = Color(0xFFFFEDE0);
  static const Color peach = Color(0xFFFFE3CF);
  static const Color navy = Color(0xFF1B2A4A);
  static const Color ink = Color(0xFF1C1E21);
  static const Color muted = Color(0xFF5B616B);
  static const Color line = Color(0xFFD9DCE1);

  /// Control borders and meaningful icons need 3:1; `line` is for dividers.
  static const Color control = Color(0xFF868C96);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF6F7F9);

  static const Color success = Color(0xFF15803D);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFB91C1C);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoSoft = Color(0xFFDBEAFE);
}

abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;

  /// Phone gutter; the app column never grows past [maxContentWidth].
  static const double gutter = 16;
  static const double maxContentWidth = 560;
  static const double minTap = 48;
}

abstract final class Radii {
  static const double control = 8;
  static const double card = 12;
  static const double sheet = 16;
  static const double pill = 999;
}

abstract final class Motion {
  static const Duration press = Duration(milliseconds: 150);
  static const Duration enter = Duration(milliseconds: 220);
  static const Curve curve = Curves.easeOut;
}
