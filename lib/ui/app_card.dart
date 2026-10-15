import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// White (light) / slate (dark) rounded card. Tappable when [onTap] is set.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final bool shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.onTap,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = Radii.xl,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Radii.all(radius),
        boxShadow: shadow && borderColor == null ? c.cardShadow : null,
      ),
      child: Material(
        color: color ?? c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.all(radius),
          side: borderColor == null ? BorderSide.none : BorderSide(color: borderColor!, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small upper-case heading above a group ("START WORK", "ITEMS").
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionLabel(this.text,
      {super.key,
      this.trailing,
      this.padding = const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.sm)});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        );
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(child: Text(text.toUpperCase(), style: style)),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// "Label    value" row for detail screens.
class KeyValueRow extends StatelessWidget {
  final String label;
  final String? value;
  final double labelWidth;

  const KeyValueRow(this.label, this.value, {super.key, this.labelWidth = 104});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: labelWidth, child: Text(label, style: t.bodySmall)),
        Expanded(
          child: Text(
            (value == null || value!.isEmpty) ? '–' : value!,
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}
