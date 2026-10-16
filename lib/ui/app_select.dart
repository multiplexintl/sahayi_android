import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Looks like a field; tapping opens a bottom sheet to pick one item.
/// Bottom sheets are easier to use on a small scanner than drop-down menus,
/// and long lists get a search box.
class AppSelectField<T> extends StatelessWidget {
  final String? label;
  final String placeholder;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final String? Function(T item)? itemSubtitle;
  final ValueChanged<T>? onChanged;
  final bool enabled;
  final IconData? icon;

  /// Show a search box when the list is longer than this.
  final int searchFrom;

  const AppSelectField({
    super.key,
    this.label,
    required this.placeholder,
    required this.value,
    required this.items,
    required this.itemLabel,
    this.itemSubtitle,
    required this.onChanged,
    this.enabled = true,
    this.icon,
    this.searchFrom = 8,
  });

  /// Opens the list of the field that carries [key] (e.g. to move on from
  /// the field before it). Does nothing if that field is not on screen.
  static void openByKey(GlobalKey key) {
    final field = key.currentWidget;
    final context = key.currentContext;
    if (field is AppSelectField && context != null) {
      field._openIfActive(context);
    }
  }

  // Checked inside the field, where T is known (reading onChanged through
  // AppSelectField<dynamic> fails at runtime).
  void _openIfActive(BuildContext context) {
    if (enabled && onChanged != null) _open(context);
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SelectSheet<T>(
        title: label ?? placeholder,
        items: items,
        selected: value,
        itemLabel: itemLabel,
        itemSubtitle: itemSubtitle,
        searchable: items.length > searchFrom,
      ),
    );
    if (picked != null) onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final theme = Theme.of(context).textTheme;
    final active = enabled && onChanged != null;
    final box = Material(
      color: active ? c.surface : c.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.all(Radii.md),
        side: BorderSide(color: active ? c.border : c.divider, width: 1.5),
      ),
      child: InkWell(
        borderRadius: Radii.all(Radii.md),
        onTap: active ? () => _open(context) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: Sizes.control),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            if (icon != null) ...[
              Icon(icon, size: Sizes.iconSm + 2, color: c.muted),
              const SizedBox(width: 10)
            ],
            Expanded(
              child: Text(
                value == null ? placeholder : itemLabel(value as T),
                overflow: TextOverflow.ellipsis,
                style: value == null
                    ? theme.bodyLarge?.copyWith(color: c.faint)
                    : theme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: active ? c.text : c.muted),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: active ? c.muted : c.disabledFg),
          ]),
        ),
      ),
    );
    if (label == null) return box;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: Space.xs + 2),
          child: Text(label!, style: theme.labelMedium),
        ),
        box,
      ],
    );
  }
}

class _SelectSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final T? selected;
  final String Function(T) itemLabel;
  final String? Function(T)? itemSubtitle;
  final bool searchable;

  const _SelectSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.itemLabel,
    required this.itemSubtitle,
    required this.searchable,
  });

  @override
  State<_SelectSheet<T>> createState() => _SelectSheetState<T>();
}

class _SelectSheetState<T> extends State<_SelectSheet<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final theme = Theme.of(context).textTheme;
    final q = _q.toLowerCase();
    final shown = q.isEmpty
        ? widget.items
        : widget.items.where((i) {
            final s =
                '${widget.itemLabel(i)} ${widget.itemSubtitle?.call(i) ?? ''}'
                    .toLowerCase();
            return s.contains(q);
          }).toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.md),
              child: Text(widget.title, style: theme.titleLarge),
            ),
            if (widget.searchable)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
            Flexible(
              child: shown.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Text('Nothing matches "$_q"',
                          textAlign: TextAlign.center, style: theme.bodySmall),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(
                          Space.sm, 0, Space.sm, Space.lg),
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final item = shown[i];
                        final selected = item == widget.selected;
                        final sub = widget.itemSubtitle?.call(item);
                        return ListTile(
                          selected: selected,
                          selectedTileColor: c.primarySoft,
                          selectedColor: c.onPrimarySoft,
                          title: Text(widget.itemLabel(item)),
                          subtitle: sub == null ? null : Text(sub),
                          trailing: selected
                              ? Icon(Icons.check_rounded,
                                  color: c.onPrimarySoft)
                              : null,
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
