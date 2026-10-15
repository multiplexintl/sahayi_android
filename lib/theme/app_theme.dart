import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Version 2 theme ("Harbor"): light and dark, Plus Jakarta Sans.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'PlusJakartaSans';

  static ThemeData get light => _build(AppColors.light, Brightness.light);
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  /// Type scale (from the approved mock-up).
  static TextTheme _textTheme(AppColors c) {
    TextStyle s(double size, FontWeight w, Color color, {double? ls, double? h}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: w,
          color: color,
          letterSpacing: ls,
          height: h,
        );
    return TextTheme(
      displaySmall: s(28, FontWeight.w800, c.text, ls: -0.5),
      headlineSmall: s(22, FontWeight.w800, c.text, ls: -0.2), // screen titles
      titleLarge: s(18, FontWeight.w800, c.text, ls: -0.1),
      titleMedium: s(17, FontWeight.w700, c.text), // section headings
      titleSmall: s(15, FontWeight.w700, c.text),
      bodyLarge: s(15, FontWeight.w500, c.text, h: 1.35), // body
      bodyMedium: s(14, FontWeight.w500, c.text, h: 1.35),
      bodySmall: s(13, FontWeight.w500, c.muted, h: 1.3), // captions
      labelLarge: s(15, FontWeight.w700, c.text), // buttons
      labelMedium: s(13, FontWeight.w600, c.muted), // field labels
      labelSmall: s(12, FontWeight.w600, c.muted, ls: 0.2),
    );
  }

  static ThemeData _build(AppColors c, Brightness b) {
    final text = _textTheme(c);
    final scheme = ColorScheme(
      brightness: b,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.onPrimarySoft,
      secondary: c.accent,
      onSecondary: c.text,
      secondaryContainer: c.accentSoft,
      onSecondaryContainer: c.accentText,
      error: c.danger,
      onError: c.onPrimary,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.dangerText,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.muted,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surface,
      surfaceContainerHighest: c.surfaceAlt,
      outline: c.border,
      outlineVariant: c.divider,
      shadow: Colors.black,
      inverseSurface: c.text,
      onInverseSurface: c.background,
    );

    final shape12 = RoundedRectangleBorder(borderRadius: Radii.all(Radii.md));
    final shape14 = RoundedRectangleBorder(borderRadius: Radii.all(Radii.lg));

    OutlineInputBorder border(Color color, [double w = 1.5]) => OutlineInputBorder(
          borderRadius: Radii.all(Radii.md),
          borderSide: BorderSide(color: color, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.divider,
      extensions: [c],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,

      // Same look as AppTopBar: card colour + bottom line.
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: c.border)),
        systemOverlayStyle: b == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        centerTitle: false,
        toolbarHeight: Sizes.appBar,
        titleSpacing: 4,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: c.text, size: Sizes.icon),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.disabledBg,
          disabledForegroundColor: c.disabledFg,
          minimumSize: const Size(Sizes.control, Sizes.control),
          shape: shape14,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.disabledBg,
          disabledForegroundColor: c.disabledFg,
          minimumSize: const Size(Sizes.control, Sizes.control),
          shape: shape14,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: c.surface,
          foregroundColor: c.text,
          disabledForegroundColor: c.disabledFg,
          minimumSize: const Size(Sizes.control, Sizes.control),
          side: BorderSide(color: c.border, width: 1.5),
          shape: shape14,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(Sizes.controlCompact, Sizes.controlCompact),
          shape: shape12,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: const Size(Sizes.controlCompact, Sizes.controlCompact),
          shape: shape12,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: text.labelMedium,
        floatingLabelStyle: text.labelMedium?.copyWith(color: c.primary),
        hintStyle: text.bodyLarge?.copyWith(color: c.faint),
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
        errorStyle: text.bodySmall?.copyWith(color: c.dangerText),
        border: border(c.border),
        enabledBorder: border(c.border),
        disabledBorder: border(c.divider),
        focusedBorder: border(c.primary, 2),
        errorBorder: border(c.danger),
        focusedErrorBorder: border(c.danger, 2),
      ),

      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Radii.all(Radii.xl)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Radii.all(Radii.xxl)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge?.copyWith(color: c.muted),
        insetPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xl),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.text,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.background),
        shape: shape14,
        insetPadding: const EdgeInsets.all(Space.md),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primarySoft,
        side: BorderSide(color: c.border),
        labelStyle: text.labelSmall?.copyWith(color: c.text),
        shape: RoundedRectangleBorder(borderRadius: Radii.all(Radii.pill)),
      ),
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceAlt,
        circularTrackColor: c.surfaceAlt,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        textColor: c.text,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        shape: shape12,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.faint),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceAlt),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.primary : Colors.transparent),
        side: BorderSide(color: c.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: Radii.all(5)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.primary,
        headerForegroundColor: c.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: Radii.all(Radii.xxl)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.primary,
        unselectedLabelColor: c.muted,
        indicatorColor: c.primary,
        dividerColor: c.divider,
        labelStyle: text.labelLarge?.copyWith(fontSize: 13),
        unselectedLabelStyle: text.labelMedium,
      ),
    );
  }
}
