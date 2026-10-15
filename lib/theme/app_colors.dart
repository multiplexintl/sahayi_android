import 'package:flutter/material.dart';

/// Version 2 "Harbor" palette. Medium contrast for dim warehouses.
///
/// Read it in widgets with `context.c` (see [AppColorsX]); never hard-code
/// colours in screens.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  // Brand
  final Color primary;
  final Color onPrimary;
  final Color primarySoft; // tinted background for primary icons / chips
  final Color onPrimarySoft; // text/icons placed ON primarySoft
  final Color accent; // amber: highlight, "currently scanning"
  final Color accentSoft;
  final Color accentText;

  // Surfaces and text
  final Color background;
  final Color surface; // cards, inputs, sheets
  final Color surfaceAlt; // subtle fills (track, neutral chips)
  final Color text;
  final Color muted;
  final Color faint;
  final Color border;
  final Color divider;
  final Color focusRing;

  // Status (always used together with an icon and a word)
  final Color success;
  final Color successSoft;
  final Color successText;
  final Color successCard; // completed item card
  final Color successCardBorder;
  final Color warning;
  final Color warningSoft;
  final Color warningText;
  final Color danger; // ONLY for destructive actions and errors
  final Color dangerSoft;
  final Color dangerText;
  final Color dangerBorder;

  // Document types
  final Color invoice;
  final Color invoiceSoft;
  final Color transfer;
  final Color transferSoft;
  final Color returnC;
  final Color returnSoft;

  // Disabled controls
  final Color disabledBg;
  final Color disabledFg;

  /// Card shadow (light) or hairline outline (dark).
  final List<BoxShadow> cardShadow;

  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.accent,
    required this.accentSoft,
    required this.accentText,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.muted,
    required this.faint,
    required this.border,
    required this.divider,
    required this.focusRing,
    required this.success,
    required this.successSoft,
    required this.successText,
    required this.successCard,
    required this.successCardBorder,
    required this.warning,
    required this.warningSoft,
    required this.warningText,
    required this.danger,
    required this.dangerSoft,
    required this.dangerText,
    required this.dangerBorder,
    required this.invoice,
    required this.invoiceSoft,
    required this.transfer,
    required this.transferSoft,
    required this.returnC,
    required this.returnSoft,
    required this.disabledBg,
    required this.disabledFg,
    required this.cardShadow,
  });

  static const light = AppColors(
    primary: Color(0xFF0E7C7B),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFE3F2F1),
    onPrimarySoft: Color(0xFF0B6463),
    accent: Color(0xFFE8A33D),
    accentSoft: Color(0xFFFFF8EC),
    accentText: Color(0xFF9A6214),
    background: Color(0xFFF3F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF1F4),
    text: Color(0xFF1F2933),
    muted: Color(0xFF5B6773),
    faint: Color(0xFF7A8794),
    border: Color(0xFFD5DDE4),
    divider: Color(0xFFE2E7EC),
    focusRing: Color(0x1F0E7C7B),
    success: Color(0xFF2E9E6A),
    successSoft: Color(0xFFE6F4EE),
    successText: Color(0xFF1F7A50),
    successCard: Color(0xFFF1F8F4),
    successCardBorder: Color(0xFFD5EBDF),
    warning: Color(0xFFD9902B),
    warningSoft: Color(0xFFFBF1E2),
    warningText: Color(0xFF9A6214),
    danger: Color(0xFFD64545),
    dangerSoft: Color(0xFFFDF1F1),
    dangerText: Color(0xFFB83A3A),
    dangerBorder: Color(0xFFF1C6C6),
    invoice: Color(0xFF0B6463),
    invoiceSoft: Color(0xFFE3F2F1),
    transfer: Color(0xFF3C47A3),
    transferSoft: Color(0xFFE8EAF8),
    returnC: Color(0xFFA9472B),
    returnSoft: Color(0xFFFCEBE5),
    disabledBg: Color(0xFFE2E7EC),
    disabledFg: Color(0xFF6B7784),
    cardShadow: [
      BoxShadow(color: Color(0x0D101828), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0D101828), blurRadius: 16, offset: Offset(0, 6)),
    ],
  );

  static const dark = AppColors(
    primary: Color(0xFF4FD1C5),
    onPrimary: Color(0xFF0B1F1E),
    primarySoft: Color(0xFF173A3A),
    onPrimarySoft: Color(0xFF4FD1C5),
    accent: Color(0xFFF2B85B),
    accentSoft: Color(0xFF2B2416),
    accentText: Color(0xFFF2B85B),
    background: Color(0xFF12171D),
    surface: Color(0xFF1B222A),
    surfaceAlt: Color(0xFF2A333D),
    text: Color(0xFFE6EBF0),
    muted: Color(0xFF9AA6B2),
    faint: Color(0xFF6E7A86),
    border: Color(0xFF323C47),
    divider: Color(0xFF242C35),
    focusRing: Color(0x2E4FD1C5),
    success: Color(0xFF4CC38A),
    successSoft: Color(0xFF1E3A2D),
    successText: Color(0xFF4CC38A),
    successCard: Color(0xFF16241E),
    successCardBorder: Color(0xFF234034),
    warning: Color(0xFFE8B04A),
    warningSoft: Color(0xFF3A2E19),
    warningText: Color(0xFFF2B85B),
    danger: Color(0xFFF07070),
    dangerSoft: Color(0xFF3A1F22),
    dangerText: Color(0xFFF59A9A),
    dangerBorder: Color(0xFF5A2D31),
    invoice: Color(0xFF4FD1C5),
    invoiceSoft: Color(0xFF163634),
    transfer: Color(0xFF9AA4F2),
    transferSoft: Color(0xFF24284A),
    returnC: Color(0xFFF29A7E),
    returnSoft: Color(0xFF3A2620),
    disabledBg: Color(0xFF242C35),
    disabledFg: Color(0xFF7A8794),
    cardShadow: [BoxShadow(color: Color(0xFF242C35), spreadRadius: 1)],
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      (other is AppColors && t >= 0.5) ? other : this;
}

extension AppColorsX on BuildContext {
  /// The Version 2 palette for the current light/dark mode. Falls back to
  /// the matching built-in palette if the theme does not carry it.
  AppColors get c {
    final theme = Theme.of(this);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light);
  }
}
