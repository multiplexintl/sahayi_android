import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';

/// "18 of 42 items done" with a progress bar.
class ProgressCard extends StatelessWidget {
  final int done;
  final int total;
  final String unit;

  const ProgressCard({super.key, required this.done, required this.total, this.unit = 'items'});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = Theme.of(context).textTheme;
    final ratio = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final complete = total > 0 && done >= total;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, Space.md, 14, Space.md),
      radius: Radii.lg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
              complete ? 'All $total $unit done' : '$done of $total $unit done',
              style: t.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          Text('${(ratio * 100).round()}%',
              style: t.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: Space.sm),
        AppProgressBar(value: ratio, color: complete ? c.success : c.primary),
      ]),
    );
  }
}

class AppProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;

  const AppProgressBar({super.key, required this.value, this.color, this.height = 8});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: Radii.all(Radii.pill),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        color: color ?? context.c.primary,
        backgroundColor: context.c.surfaceAlt,
      ),
    );
  }
}
