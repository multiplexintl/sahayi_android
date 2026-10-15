import 'package:flutter/widgets.dart';

/// Spacing, corner radius and sizes shared by every Version 2 screen.
/// Laid out for the EDA52 (360 x 640 logical px).
class Space {
  Space._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  /// Side margin of screen content.
  static const double screen = 12;
}

class Radii {
  Radii._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 18;
  static const double xxl = 20;
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);
}

class Sizes {
  Sizes._();

  /// Minimum touch target and standard control height.
  static const double control = 48;
  static const double controlCompact = 44;
  static const double icon = 22;
  static const double iconSm = 18;
  static const double appBar = 52;
}
