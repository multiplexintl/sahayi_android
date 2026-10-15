import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Puts one screen into the Version 2 theme while the rest of the app still
/// runs on Version 1. Once every screen is converted the app switches its
/// global theme (and dark mode) and this wrapper becomes a no-op.
class V2Screen extends StatelessWidget {
  final Widget child;
  const V2Screen({super.key, required this.child});

  /// Light only during the transition: Version 1 screens have hard-coded
  /// white backgrounds and would be unreadable in dark mode.
  static ThemeData get theme => AppTheme.light;

  @override
  Widget build(BuildContext context) => Theme(data: theme, child: child);
}
