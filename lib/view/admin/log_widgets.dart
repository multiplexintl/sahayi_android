import 'package:flutter/material.dart';
import 'package:sahayi_android/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../model/log_filter.dart';

/// Shared pieces for the logs dashboard tabs.

/// Dashboard date format, e.g. 14/10/2026 02:35 PM
final DateFormat logTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');
final DateFormat logShortTimeFormat = logTimeFormat;

/// Level colour for the current light/dark theme.
Color levelColor(String? level) {
  final context = Get.context;
  final c = context == null ? AppColors.light : context.c;
  return switch (level) {
    'ERROR' => c.dangerText,
    'WARN' => c.warningText,
    _ => c.muted,
  };
}

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

/// One scrollable row of one-tap filters (All, Errors, Network, ...).
class PresetChips extends StatelessWidget {
  final LogFilter filter;
  final ValueChanged<LogPreset> onSelected;
  final bool showWaiting; // "Waiting upload" only makes sense on this device
  const PresetChips(
      {super.key, required this.filter, required this.onSelected, this.showWaiting = true});

  @override
  Widget build(BuildContext context) {
    final current = LogPreset.matching(filter);
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final p in LogPreset.values)
            if (showWaiting || p != LogPreset.waiting)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(p.label, style: const TextStyle(fontSize: 12)),
                  selected: current == p,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  onSelected: (_) => onSelected(p),
                ),
              ),
          if (current == null)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Chip(
                label: Text('Custom', style: TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

/// Search box + date button + "more filters" button, in one row.
class FilterBar extends StatelessWidget {
  final TextEditingController search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final LogFilter filter;
  final void Function(DateTime? from, DateTime? to) onDates;
  final VoidCallback onMoreFilters;
  const FilterBar({
    super.key,
    required this.search,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.filter,
    required this.onDates,
    required this.onMoreFilters,
  });

  @override
  Widget build(BuildContext context) {
    final active = Theme.of(context).colorScheme.primary;
    final dateSet = filter.from != null;
    final more = filter.activeCount - (dateSet ? 1 : 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 2),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: search,
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                prefixIcon: const Icon(Icons.search, size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 32),
                hintText: 'Search',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: onClearSearch,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: dateSet ? 'Dates (long-press to clear)' : 'Dates',
          visualDensity: VisualDensity.compact,
          icon: Icon(dateSet ? Icons.event_available : Icons.date_range,
              color: dateSet ? active : null),
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: context,
              firstDate: now.subtract(const Duration(days: 120)),
              lastDate: now,
              initialDateRange: filter.from == null
                  ? null
                  : DateTimeRange(start: filter.from!, end: filter.to ?? filter.from!),
            );
            if (picked != null) onDates(picked.start, picked.end);
          },
        ),
        IconButton(
          tooltip: 'More filters',
          visualDensity: VisualDensity.compact,
          onPressed: onMoreFilters,
          icon: Badge(
            isLabelVisible: more > 0,
            label: Text('$more'),
            child: Icon(Icons.tune, color: more > 0 ? active : null),
          ),
        ),
      ]),
    );
  }
}

/// Small line under the filter bar when dates are set, with a clear (x).
class ActiveDatesLine extends StatelessWidget {
  final LogFilter filter;
  final VoidCallback onClear;
  const ActiveDatesLine({super.key, required this.filter, required this.onClear});

  @override
  Widget build(BuildContext context) {
    if (filter.from == null) return const SizedBox.shrink();
    final f = DateFormat('dd/MM/yyyy');
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(children: [
        Text('${f.format(filter.from!)} → ${f.format(filter.to ?? filter.from!)}',
            style: Theme.of(context).textTheme.labelSmall),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          icon: const Icon(Icons.close),
          onPressed: onClear,
        ),
      ]),
    );
  }
}

/// Bottom sheet with every filter. Returns the new filter, or null if cancelled.
class FilterSheet extends StatefulWidget {
  final LogFilter initial;
  final Future<List<({String value, int count})>> Function(String column) valuesOf;
  final bool showUploadState;
  const FilterSheet({
    super.key,
    required this.initial,
    required this.valuesOf,
    this.showUploadState = true,
  });

  static Future<LogFilter?> show(BuildContext context,
          {required LogFilter initial,
          required Future<List<({String value, int count})>> Function(String column) valuesOf,
          bool showUploadState = true}) =>
      showModalBottomSheet<LogFilter>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FilterSheet(
            initial: initial, valuesOf: valuesOf, showUploadState: showUploadState),
      );

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late LogFilter f = widget.initial;
  final _values = <String, List<({String value, int count})>>{};

  @override
  void initState() {
    super.initState();
    for (final c in ['Action', 'Screen', 'UserID']) {
      widget.valuesOf(c).then((v) {
        if (mounted) setState(() => _values[c] = v);
      }).catchError((_) {});
    }
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          child,
        ]),
      );

  Widget _chips<T>(List<(String, T)> options, T selected, ValueChanged<T> onTap) => Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final (label, value) in options)
            ChoiceChip(
              label: Text(label),
              selected: selected == value,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => onTap(value),
            ),
        ],
      );

  /// Dropdown of values present in the logs. Null = any.
  Widget _dropdown(String column, String? selected, ValueChanged<String?> onChanged) {
    final values = _values[column];
    if (values == null) return const LinearProgressIndicator();
    final items = [
      const DropdownMenuItem<String?>(value: null, child: Text('Any')),
      for (final v in values)
        DropdownMenuItem<String?>(
            value: v.value,
            child: Text('${v.value}  (${v.count})', overflow: TextOverflow.ellipsis)),
      if (selected != null && !values.any((v) => v.value == selected))
        DropdownMenuItem<String?>(value: selected, child: Text(selected)),
    ];
    return DropdownButton<String?>(
      isExpanded: true,
      isDense: true,
      value: selected,
      items: items,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final action = f.actions.length == 1 ? f.actions.first : null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            Row(children: [
              Text('Filters', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => f = LogFilter(from: f.from, to: f.to)),
                child: const Text('Reset'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(f),
                child: const Text('Apply'),
              ),
            ]),
            _section(
              'Level (any of)',
              Wrap(spacing: 6, children: [
                for (final level in ['ERROR', 'WARN', 'INFO'])
                  FilterChip(
                    label: Text(level),
                    selected: f.levels.contains(level),
                    selectedColor: levelColor(level).withValues(alpha: 0.2),
                    visualDensity: VisualDensity.compact,
                    onSelected: (on) => setState(() => f = f.copyWith(
                        levels: on ? {...f.levels, level} : ({...f.levels}..remove(level)))),
                  ),
              ]),
            ),
            _section(
              f.actions.length > 1
                  ? 'Action (${f.actions.length} selected by a quick filter)'
                  : 'Action',
              _dropdown('Action', action,
                  (v) => setState(() => f = f.copyWith(actions: v == null ? {} : {v}))),
            ),
            _section('Screen',
                _dropdown('Screen', f.screen, (v) => setState(() => f = f.copyWith(screen: () => v)))),
            _section('User',
                _dropdown('UserID', f.userId, (v) => setState(() => f = f.copyWith(userId: () => v)))),
            _section(
              'Document type',
              _chips<String?>(
                [('Any', null), ('Invoice', 'I'), ('Transfer', 'T'), ('Return', 'R')],
                f.docType,
                (v) => setState(() => f = f.copyWith(docType: () => v)),
              ),
            ),
            if (widget.showUploadState)
              _section(
                'Upload',
                _chips<int?>(
                  [('Any', null), ('Waiting', 0), ('Sent', 1), ('Rejected', 2)],
                  f.uploadState,
                  (v) => setState(() => f = f.copyWith(uploadState: () => v)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One log in a list (both tabs). Line 1: level + action (+ trailing icon);
/// line 2: message; line 3: time · user · doc · screen. Nothing in the first
/// line has a fixed width except the badge and icon, so it fits small screens
/// and large fonts.
class LogTile extends StatelessWidget {
  final String? level;
  final String action;
  final String message;
  final DateTime time;
  final List<String?> meta;
  final IconData? trailingIcon;
  final VoidCallback onTap;
  const LogTile({
    super.key,
    required this.level,
    required this.action,
    required this.message,
    required this.time,
    this.meta = const [],
    this.trailingIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              LevelBadge(level),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(action,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis)),
              if (trailingIcon != null) Icon(trailingIcon, size: 13, color: context.c.faint),
            ]),
            const SizedBox(height: 2),
            Text(message,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            Text(
                [logTimeFormat.format(time), ...meta.whereType<String>().where((m) => m.isNotEmpty)]
                    .join(' · '),
                style: small,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
