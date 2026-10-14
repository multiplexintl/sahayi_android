import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Shared pieces for the logs dashboard tabs.

final DateFormat logTimeFormat = DateFormat('dd-MM-yyyy HH:mm:ss');
final DateFormat logShortTimeFormat = DateFormat('dd-MM HH:mm:ss');

Color levelColor(String? level) => switch (level) {
      'ERROR' => Colors.red,
      'WARN' => Colors.orange,
      _ => Colors.blueGrey,
    };

class LevelBadge extends StatelessWidget {
  final String? level;
  const LevelBadge(this.level, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: levelColor(level).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: levelColor(level)),
        ),
        child: Text(level ?? '?',
            style: TextStyle(
                color: levelColor(level), fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

/// One number in the status header.
class CountTile extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;
  const CountTile(this.label, this.value, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text('$value',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      );
}

/// Level filter: All / ERROR / WARN / INFO.
class LevelFilter extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;
  const LevelFilter({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        children: [
          for (final level in [null, 'ERROR', 'WARN', 'INFO'])
            ChoiceChip(
              label: Text(level ?? 'All'),
              selected: selected == level,
              visualDensity: VisualDensity.compact,
              selectedColor: level == null ? null : levelColor(level).withValues(alpha: 0.2),
              onSelected: (_) => onChanged(level),
            ),
        ],
      );
}

/// Date range button: "Any date" or "01-10 → 14-10", with a clear (x).
class DateRangeButton extends StatelessWidget {
  final DateTime? from;
  final DateTime? to; // inclusive day shown to the user
  final void Function(DateTime? from, DateTime? to) onChanged;
  const DateRangeButton(
      {super.key, required this.from, required this.to, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd-MM');
    final label = from == null ? 'Any date' : '${f.format(from!)} → ${f.format(to ?? from!)}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range, size: 18),
          label: Text(label),
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: context,
              firstDate: now.subtract(const Duration(days: 120)),
              lastDate: now,
              initialDateRange:
                  from == null ? null : DateTimeRange(start: from!, end: to ?? from!),
            );
            if (picked != null) onChanged(picked.start, picked.end);
          },
        ),
        if (from != null)
          IconButton(
            tooltip: 'Any date',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => onChanged(null, null),
          ),
      ],
    );
  }
}

/// Full details of one log, with a Copy button (for WhatsApp / email).
class LogDetailPage extends StatelessWidget {
  final String title;
  final Map<String, String?> fields;
  const LogDetailPage({super.key, required this.title, required this.fields});

  static void open(String title, Map<String, String?> fields) =>
      Get.to(() => LogDetailPage(title: title, fields: fields));

  String get _asText => fields.entries
      .where((e) => e.value != null && e.value!.isNotEmpty)
      .map((e) => '${e.key}: ${e.value}')
      .join('\n');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _asText));
              Get.snackbar('Copied', 'Log details copied to the clipboard',
                  snackPosition: SnackPosition.BOTTOM);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final e in fields.entries)
            if (e.value != null && e.value!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 2),
                    SelectableText(e.value!,
                        style: e.key == 'Details'
                            ? const TextStyle(fontFamily: 'monospace', fontSize: 12)
                            : null),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
