import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'badges.dart';

/// [plain]: neutral card with an optional neutral label (reports, history).
enum ItemState { todo, partial, active, done, error, plain }

/// One line of a document: name, codes, quantity and a status chip.
/// [ItemState.active] (amber) marks the item being scanned right now.
class ItemCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String quantity;
  final ItemState state;
  final String? statusLabel;
  final String? leading; // e.g. line number
  final Widget? trailing; // e.g. delete / view button
  final VoidCallback? onTap;
  final int titleMaxLines;

  const ItemCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.quantity,
    required this.state,
    this.statusLabel,
    this.leading,
    this.trailing,
    this.onTap,
    this.titleMaxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = Theme.of(context).textTheme;
    final (Color bg, Color border, double bw) = switch (state) {
      ItemState.done => (c.successCard, c.successCardBorder, 1.0),
      ItemState.active => (c.accentSoft, c.accent, 1.5),
      ItemState.error => (c.dangerSoft, c.dangerBorder, 1.0),
      ItemState.todo => (c.surface, c.divider, 1.0),
      ItemState.partial => (c.surface, c.divider, 1.0),
      ItemState.plain => (c.surface, c.divider, 1.0),
    };
    final chip = switch (state) {
      ItemState.done => StatusChip.done(statusLabel ?? 'Done', small: true),
      ItemState.active => StatusChip(
          kind: StatusKind.warning, label: statusLabel ?? 'Scanning', icon: Icons.qr_code_scanner_rounded, small: true),
      ItemState.error => StatusChip.error(statusLabel ?? 'Mismatch', small: true),
      ItemState.todo => StatusChip.todo(statusLabel ?? 'To do', small: true),
      ItemState.partial => StatusChip.progress(statusLabel ?? 'Partial', small: true),
      ItemState.plain => (statusLabel == null || statusLabel!.isEmpty)
          ? const SizedBox.shrink()
          : StatusChip(kind: StatusKind.neutral, label: statusLabel!, small: true),
    };

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: Radii.all(Radii.lg), side: BorderSide(color: border, width: bw)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 10),
          child: Row(children: [
            if (leading != null) ...[
              SizedBox(
                width: 26,
                child: Text(leading!, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    maxLines: titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
              ]),
            ),
            const SizedBox(width: Space.sm),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(quantity,
                  style: t.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(height: 4),
              chip,
            ]),
            if (trailing != null) ...[const SizedBox(width: Space.xs), trailing!],
          ]),
        ),
      ),
    );
  }
}
