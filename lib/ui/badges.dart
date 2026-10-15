import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

enum StatusKind { success, warning, danger, neutral, info }

/// Pill with an icon AND a word, never colour alone.
class StatusChip extends StatelessWidget {
  final StatusKind kind;
  final String label;
  final IconData? icon;
  final bool small;

  const StatusChip({super.key, required this.kind, required this.label, this.icon, this.small = false});

  const StatusChip.done(this.label, {super.key, this.small = false})
      : kind = StatusKind.success,
        icon = Icons.check_rounded;
  const StatusChip.progress(this.label, {super.key, this.small = false})
      : kind = StatusKind.warning,
        icon = Icons.schedule_rounded;
  const StatusChip.error(this.label, {super.key, this.small = false})
      : kind = StatusKind.danger,
        icon = Icons.close_rounded;
  const StatusChip.todo(this.label, {super.key, this.small = false})
      : kind = StatusKind.neutral,
        icon = Icons.radio_button_unchecked_rounded;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (Color bg, Color fg) = switch (kind) {
      StatusKind.success => (c.successSoft, c.successText),
      StatusKind.warning => (c.warningSoft, c.warningText),
      StatusKind.danger => (c.dangerSoft, c.dangerText),
      StatusKind.info => (c.primarySoft, c.onPrimarySoft),
      StatusKind.neutral => (c.surfaceAlt, c.muted),
    };
    final size = small ? 11.0 : 13.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 2 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: Radii.all(Radii.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: size + 1, color: fg), const SizedBox(width: 4)],
        Text(label,
            style: TextStyle(
                fontSize: size, fontWeight: FontWeight.w800, color: fg, height: 1.2)),
      ]),
    );
  }
}

/// Document type label: Invoice (I), Transfer (T), Return (R).
class DocTypeBadge extends StatelessWidget {
  final String? type;
  final bool upperCase;

  const DocTypeBadge(this.type, {super.key, this.upperCase = true});

  static String labelOf(String? type) => switch (type) {
        'I' => 'Invoice',
        'T' => 'Transfer',
        'R' => 'Return',
        _ => 'Document',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (Color bg, Color fg) = switch (type) {
      'I' => (c.invoiceSoft, c.invoice),
      'T' => (c.transferSoft, c.transfer),
      'R' => (c.returnSoft, c.returnC),
      _ => (c.surfaceAlt, c.muted),
    };
    final text = labelOf(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: Radii.all(6)),
      child: Text(upperCase ? text.toUpperCase() : text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.4)),
    );
  }
}
