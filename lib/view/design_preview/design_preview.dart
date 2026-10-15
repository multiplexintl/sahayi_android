import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// Version 2 design system preview: every shared component in light or dark.
/// Uses its own theme, so it works before the app itself switches to v2.
class DesignPreviewScreen extends StatefulWidget {
  const DesignPreviewScreen({super.key});

  @override
  State<DesignPreviewScreen> createState() => _DesignPreviewScreenState();
}

class _DesignPreviewScreenState extends State<DesignPreviewScreen> {
  bool _dark = false;
  bool _loading = false;
  String? _company;
  final _barcode = TextEditingController(text: '6858475398443');
  final _qty = TextEditingController(text: '6');

  @override
  void dispose() {
    _barcode.dispose();
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _dark ? AppTheme.dark : AppTheme.light,
      child: Builder(builder: (context) {
        final c = context.c;
        final t = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppTopBar(
            title: 'Design preview',
            subtitle: 'Version 2 · Harbor',
            actions: [
              AppIconButton(
                icon: _dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                tooltip: 'Switch light or dark',
                onPressed: () => setState(() => _dark = !_dark),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: Space.xxl),
            children: [
              const SectionLabel('Colours'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                  for (final (name, color) in [
                    ('Primary', c.primary),
                    ('Accent', c.accent),
                    ('Surface', c.surface),
                    ('Text', c.text),
                    ('Success', c.success),
                    ('Warning', c.warning),
                    ('Danger', c.danger),
                    ('Muted', c.muted),
                  ])
                    _Swatch(name: name, color: color),
                ]),
              ),

              const SectionLabel('Type'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Title · Invoice 25032700', style: t.headlineSmall),
                  Text('Heading · Scan items', style: t.titleMedium),
                  Text('Body · Jo Soap Asstd 125 GM x 6', style: t.bodyLarge),
                  Text('Caption · Kesariya & Co LLC (COD)', style: t.bodySmall),
                  Text('1,800 / 1,800',
                      style: t.headlineSmall?.copyWith(
                          color: c.primary, fontFeatures: const [FontFeature.tabularFigures()])),
                ]),
              ),

              const SectionLabel('Buttons'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: Column(children: [
                  AppButton(
                    label: 'Sync invoice',
                    icon: Icons.sync_rounded,
                    loading: _loading,
                    onPressed: () async {
                      setState(() => _loading = true);
                      await Future.delayed(const Duration(seconds: 2));
                      if (mounted) setState(() => _loading = false);
                    },
                  ),
                  const SizedBox(height: Space.sm),
                  Row(children: [
                    Expanded(child: AppButton.secondary(label: 'Clear fields', onPressed: () {})),
                    const SizedBox(width: Space.sm),
                    const Expanded(
                        child: AppButton(label: 'Finalize', disabledLabel: 'Finalize · 24 left', onPressed: null)),
                  ]),
                  const SizedBox(height: Space.sm),
                  AppButton.danger(label: 'Delete local data', icon: Icons.delete_outline_rounded, onPressed: () {}),
                  AppButton(label: 'Low-emphasis action', kind: AppButtonKind.ghost, onPressed: () {}),
                ]),
              ),

              const SectionLabel('Fields'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: Column(children: [
                  AppSelectField<String>(
                    label: 'Company',
                    placeholder: 'Select company',
                    value: _company,
                    items: const ['EPIC01 · EPIC Trading', 'EPIC02 · EPIC Retail', 'EPIC03 · EPIC Wholesale'],
                    itemLabel: (s) => s,
                    onChanged: (v) => setState(() => _company = v),
                    icon: Icons.business_rounded,
                  ),
                  const SizedBox(height: Space.md),
                  const AppTextField(label: 'Document number', hint: 'e.g. 25032700', prefixIcon: Icons.tag_rounded),
                  const SizedBox(height: Space.md),
                  Row(children: [
                    Expanded(
                      child: AppTextField(
                        controller: _barcode,
                        hint: 'Scan barcode',
                        prefixIcon: Icons.qr_code_scanner_rounded,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    SizedBox(
                      width: 64,
                      child: AppTextField(
                        controller: _qty,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    SizedBox(
                      width: 52,
                      child: AppButton(label: '', icon: Icons.check_rounded, onPressed: () {}),
                    ),
                  ]),
                ]),
              ),

              const SectionLabel('Status & document types'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: Wrap(spacing: Space.sm, runSpacing: Space.sm, children: const [
                  StatusChip.done('Completed'),
                  StatusChip.progress('18 / 42'),
                  StatusChip.error('Mismatch'),
                  StatusChip.todo('To do'),
                  DocTypeBadge('I'),
                  DocTypeBadge('T'),
                  DocTypeBadge('R'),
                ]),
              ),

              const SectionLabel('Progress'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Space.screen),
                child: ProgressCard(done: 18, total: 42),
              ),

              const SectionLabel('Item cards', trailing: Text('Checked / Shipped')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: Column(children: const [
                  ItemCard(
                      title: 'Jo Soap Asstd 125 GM x 6',
                      subtitle: 'JOS0398443 · 6858475398443',
                      quantity: '1,200 / 1,800',
                      state: ItemState.active),
                  SizedBox(height: Space.sm),
                  ItemCard(
                      title: 'Jo Shampoo Herbal 400 ML',
                      subtitle: 'JOS0412205 · 6858475412205',
                      quantity: '600 / 600',
                      state: ItemState.done),
                  SizedBox(height: Space.sm),
                  ItemCard(
                      title: 'Jo Detergent 1 KG',
                      subtitle: 'JOD1000042 · 6858475100042',
                      quantity: '0 / 120',
                      state: ItemState.todo),
                  SizedBox(height: Space.sm),
                  ItemCard(
                      title: 'Jo Dish Liquid 500 ML',
                      subtitle: 'JOL0500311 · 6858475500311',
                      quantity: '110 / 96',
                      state: ItemState.error,
                      statusLabel: 'Too many'),
                ]),
              ),

              const SectionLabel('Home actions'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: Space.md,
                  crossAxisSpacing: Space.md,
                  childAspectRatio: 1.05,
                  children: [
                    ActionTile(
                        icon: Icons.receipt_long_rounded,
                        title: 'Invoice',
                        subtitle: 'Check an outgoing invoice',
                        iconColor: c.invoice,
                        iconBackground: c.invoiceSoft,
                        onTap: () {}),
                    ActionTile(
                        icon: Icons.swap_horiz_rounded,
                        title: 'Transfer',
                        subtitle: 'Check a store transfer',
                        iconColor: c.transfer,
                        iconBackground: c.transferSoft,
                        onTap: () {}),
                  ],
                ),
              ),

              const SectionLabel('Details'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Space.screen),
                child: AppCard(
                  child: Column(children: [
                    KeyValueRow('Customer', 'Kesariya & Co LLC (COD)'),
                    KeyValueRow('Doc date', '20/03/2025'),
                    KeyValueRow('Picked by', 'EX0085'),
                  ]),
                ),
              ),

              const SectionLabel('Empty state'),
              const EmptyState(title: 'All caught up', message: 'No unfinished returns on this scanner.'),

              const SectionLabel('Feedback'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: Column(children: [
                  AppButton.secondary(
                    label: 'Open confirm sheet (danger)',
                    onPressed: () => showConfirmSheet(
                      context: context,
                      title: 'Delete all items?',
                      message: '12 scanned items will be removed from this scanner. This cannot be undone.',
                      confirmLabel: 'Delete all',
                      danger: true,
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Row(children: [
                    Expanded(
                        child: AppButton.secondary(
                            label: 'Success toast',
                            onPressed: () => AppToast.success('Saved', 'Quantity updated'))),
                    const SizedBox(width: Space.sm),
                    Expanded(
                        child: AppButton.secondary(
                            label: 'Error toast',
                            onPressed: () => AppToast.error('Not found', 'No item for this barcode'))),
                  ]),
                ]),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String name;
  final Color color;
  const _Swatch({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: 76,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: Radii.all(Radii.md),
            border: Border.all(color: c.divider),
          ),
        ),
        const SizedBox(height: 4),
        Text(name, style: Theme.of(context).textTheme.labelSmall),
      ]),
    );
  }
}
