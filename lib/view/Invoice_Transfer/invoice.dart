import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/controller/inv_trnf_controller.dart';
import 'package:sahayi_android/routes.dart';

import '../../ui/ui.dart';

/// Invoice / Transfer hub (Version 2): step 1 Sync, step 2 Scan, recent documents.
class InvoiveTransferSceen extends StatelessWidget {
  const InvoiveTransferSceen({super.key});

  @override
  Widget build(BuildContext context) {
    final con = Get.find<InvoiceOrTransferController>();
    return Builder(builder: (context) {
      final c = context.c;
      final t = Theme.of(context).textTheme;
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
                  subtitle: 'Check every item of the downloaded $noun',
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
              final recent = con.lastInvoices;
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
                    child: AppCard(
                      radius: Radii.lg,
                      // Unfinished: continue it, or sync it again (con.openRecent)
                      onTap: doc.stat == 'Y' ? null : () => con.openRecent(doc),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: Space.md),
                      child: Row(children: [
                        Icon(
                            isInvoice
                                ? Icons.receipt_long_rounded
                                : Icons.swap_horiz_rounded,
                            color: c.muted,
                            size: Sizes.iconSm + 2),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Text('${doc.docNum}',
                              style: t.titleSmall?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ])),
                        ),
                        doc.stat == 'Y'
                            ? const StatusChip.done('Completed', small: true)
                            : const StatusChip.progress('Not completed',
                                small: true),
                        if (doc.stat != 'Y') ...[
                          const SizedBox(width: Space.xs),
                          Icon(Icons.chevron_right_rounded, color: c.muted),
                        ],
                      ]),
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
