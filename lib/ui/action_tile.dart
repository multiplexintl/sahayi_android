import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';

/// Large Home action card: tinted icon, title and a short description.
class ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback? onTap;

  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBackground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      radius: Radii.xxl,
      padding: const EdgeInsets.all(Space.lg),
      // Fits any tile height: the description shortens (…) before anything overflows.
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: iconBackground, borderRadius: Radii.all(Radii.lg)),
          child: Icon(icon, color: iconColor, size: Sizes.icon),
        ),
        const SizedBox(height: Space.sm + 2),
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Flexible(
          child: Text(subtitle, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

/// Image + title + message for empty lists ("All caught up").
class EmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final String image;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.image = 'assets/images/helper_1.png',
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset(image, width: 96, height: 96, fit: BoxFit.contain),
          const SizedBox(height: Space.md),
          Text(title, style: t.titleSmall, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: Space.xs),
            Text(message!, style: t.bodySmall, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: Space.lg), action!],
        ]),
      ),
    );
  }
}

/// Avatar with initials (Home header).
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;

  const InitialsAvatar(this.name, {super.key, this.size = 44});

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.primarySoft, borderRadius: Radii.all(Radii.lg)),
      child: Text(initialsOf(name),
          style: TextStyle(color: c.onPrimarySoft, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}
