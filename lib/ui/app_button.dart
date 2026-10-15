import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

enum AppButtonKind {
  /// Main action of a screen (teal).
  primary,

  /// Neutral action: Cancel, Clear fields, Back.
  secondary,

  /// Destructive action ONLY: delete, clear data.
  danger,

  /// Low-emphasis text button.
  ghost,
}

/// The only button used on Version 2 screens.
///
/// When [onPressed] is null the button is disabled; pass [disabledLabel] to
/// say why (e.g. "Finalize · 24 left") instead of showing a dead button.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final AppButtonKind kind;
  final IconData? icon;
  final bool iconAfter;
  final bool loading;
  final bool expand;
  final String? disabledLabel;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onLongPress,
    this.kind = AppButtonKind.primary,
    this.icon,
    this.iconAfter = false,
    this.loading = false,
    this.expand = true,
    this.disabledLabel,
    this.height = Sizes.control,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.onLongPress,
    this.icon,
    this.iconAfter = false,
    this.loading = false,
    this.expand = true,
    this.disabledLabel,
    this.height = Sizes.control,
  }) : kind = AppButtonKind.secondary;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.onLongPress,
    this.icon,
    this.iconAfter = false,
    this.loading = false,
    this.expand = true,
    this.disabledLabel,
    this.height = Sizes.control,
  }) : kind = AppButtonKind.danger;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = onPressed != null && !loading;
    final text = enabled || disabledLabel == null ? label : disabledLabel!;

    final (Color bg, Color fg, BorderSide side) = switch (kind) {
      AppButtonKind.primary => (c.primary, c.onPrimary, BorderSide.none),
      AppButtonKind.secondary => (c.surface, c.text, BorderSide(color: c.border, width: 1.5)),
      AppButtonKind.danger => (c.dangerSoft, c.dangerText, BorderSide(color: c.dangerBorder, width: 1.5)),
      AppButtonKind.ghost => (Colors.transparent, c.primary, BorderSide.none),
    };

    final iconOnly = text.isEmpty && icon != null;
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : iconOnly
            ? Icon(icon, size: Sizes.icon)
            : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null && !iconAfter) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(text, overflow: TextOverflow.ellipsis, maxLines: 1)),
              if (icon != null && iconAfter) ...[const SizedBox(width: 8), Icon(icon, size: 20)],
            ],
          );

    final button = TextButton(
      onPressed: enabled ? onPressed : null,
      onLongPress: enabled ? onLongPress : null,
      style: TextButton.styleFrom(
        backgroundColor: kind == AppButtonKind.ghost ? Colors.transparent : bg,
        foregroundColor: fg,
        disabledBackgroundColor: kind == AppButtonKind.ghost ? Colors.transparent : c.disabledBg,
        disabledForegroundColor: c.disabledFg,
        minimumSize: Size(Sizes.control, height),
        fixedSize: Size.fromHeight(height),
        padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : Space.lg),
        side: enabled ? side : BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: Radii.all(Radii.lg)),
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
      child: child,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Square icon-only button (back, theme toggle, delete…). Always labelled.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? background;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.background,
    this.size = Sizes.controlCompact,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background ?? Colors.transparent,
        borderRadius: Radii.all(Radii.md),
        child: InkWell(
          borderRadius: Radii.all(Radii.md),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: Sizes.icon, color: onPressed == null ? c.disabledFg : (color ?? c.text)),
          ),
        ),
      ),
    );
  }
}
