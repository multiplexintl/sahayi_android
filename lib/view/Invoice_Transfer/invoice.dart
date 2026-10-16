import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/controller/inv_trnf_controller.dart';
import 'package:sahayi_android/routes.dart';

import '../../model/invoice/doc_master.dart';
import '../../ui/ui.dart';

/// Invoice / Transfer hub (Version 2): step 1 Sync, step 2 Scan, recent documents.
class InvoiveTransferSceen extends StatelessWidget {
  const InvoiveTransferSceen({super.key});

  @override
  Widget build(BuildContext context) {
    final con = Get.find<InvoiceOrTransferController>();
    return Builder(builder: (context) {
      final isInvoice = con.isInvoice.value;
      final noun = isInvoice ? 'invoice' : 'transfer';
      return Scaffold(
        appBar: AppTopBar(
          title: isInvoice ? 'Invoice' : 'Transfer',
          badge: DocTypeBadge(isInvoice ? 'I' : 'T'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
              Space.screen, Space.xs, Space.screen, Space.xl),
          children: [
            _StepCard(
              number: '1',
              title: 'Sync $noun',
              subtitle: 'Download the $noun from the server to this scanner',
              icon: Icons.cloud_download_rounded,
              onTap: () => Get.toNamed(RouteLinks.syncInvoice),
            ),
            const SizedBox(height: Space.md),
            Obx(() => _StepCard(
                  number: '2',
                  title: 'Scan items',
                  // what is on this scanner and how far it is
                  subtitle: con.currentDocNum.value == null
                      ? 'Check every item of the downloaded $noun'
                      : '${con.currentDocNum.value} · ${con.currentChecked.value} of ${con.currentTotal.value} units checked',
                  icon: Icons.qr_code_scanner_rounded,
                  loading: con.scanIsLoading.value,
                  onTap: con.scanIsLoading.value
                      ? null
                      : () => con.getItemsThenToScanPage(),
                )),
            SectionLabel(
              'Recent ${noun}s',
              padding: const EdgeInsets.fromLTRB(
                  Space.xs, Space.xl, Space.xs, Space.sm),
            ),
            Obx(() {
              // The one being scanned on this scanner first, then the rest as before.
              final current = con.currentDocNum.value;
              bool isCurrent(DocMaster d) =>
                  d.stat != 'Y' && d.docNum == current;
              final recent = [
                ...con.lastInvoices.where(isCurrent),
                ...con.lastInvoices.where((d) => !isCurrent(d)),
              ];
              if (recent.isEmpty) {
                return EmptyState(
                  title: 'No ${noun}s yet',
                  message: 'Synced ${noun}s will appear here.',
                );
              }
              return Column(children: [
                for (final doc in recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: _RecentCard(
                      doc: doc,
                      // "EPIC01 · Rashid K." (older entries have neither)
                      meta: [
                        doc.company,
                        con.pickerList
                                .firstWhereOrNull((p) => p.id == doc.pickedBy)
                                ?.name ??
                            doc.pickedBy,
                      ].where((v) => v != null && v.isNotEmpty).join(' · '),
                      isInvoice: isInvoice,
                      // the one downloaded on this scanner right now (step 2)
                      current: doc.stat != 'Y' &&
                          doc.docNum == con.currentDocNum.value,
                      onTap: doc.stat == 'Y' ? null : () => con.openRecent(doc),
                    ),
                  ),
              ]);
            }),
          ],
        ),
      );
    });
  }
}

/// One document in "Recent": completed, being scanned on this scanner now
/// (highlighted, tap continues), or unfinished elsewhere (tap syncs again).
class _RecentCard extends StatelessWidget {
  final DocMaster doc;
  final String meta;
  final bool isInvoice;
  final bool current;
  final VoidCallback? onTap;
  const _RecentCard(
      {required this.doc,
      this.meta = '',
      required this.isInvoice,
      required this.current,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = Theme.of(context).textTheme;
    final done = doc.stat == 'Y';
    return AppCard(
      radius: Radii.lg,
      onTap: onTap,
      color: current ? c.primarySoft : null,
      borderColor: current ? c.primary : null,
      borderWidth: 1.5,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.md),
      child: Row(children: [
        Icon(
            current
                ? Icons.qr_code_scanner_rounded
                : (isInvoice
                    ? Icons.receipt_long_rounded
                    : Icons.swap_horiz_rounded),
            color: current ? c.onPrimarySoft : c.muted,
            size: Sizes.iconSm + 2),
        const SizedBox(width: Space.md),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${doc.docNum}',
                style: t.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()])),
            if (meta.isNotEmpty)
              Text(meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall
                      ?.copyWith(color: current ? c.onPrimarySoft : null)),
            if (!done)
              Text(current ? 'Tap to continue scanning' : 'Tap to sync again',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall
                      ?.copyWith(color: current ? c.onPrimarySoft : null)),
          ]),
        ),
        if (done)
          const StatusChip.done('Completed', small: true)
        else if (current)
          const StatusChip(
              kind: StatusKind.info,
              label: 'On scanner',
              icon: Icons.play_arrow_rounded,
              small: true)
        else
          const StatusChip.progress('Not completed', small: true),
        if (!done) ...[
          const SizedBox(width: Space.xs),
          Icon(Icons.chevron_right_rounded,
              color: current ? c.onPrimarySoft : c.muted),
        ],
      ]),
    );
  }
}

/// Numbered step card ("1  Sync invoice").
class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  const _StepCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.lg),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: c.primarySoft, borderRadius: Radii.all(Radii.lg)),
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: c.primary))
              : Icon(icon, color: c.onPrimarySoft),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('STEP $number',
                style: t.labelSmall
                    ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(title, style: t.titleMedium),
            const SizedBox(height: 2),
            Text(subtitle, style: t.bodySmall),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: c.muted),
      ]),
    );
  }
}
