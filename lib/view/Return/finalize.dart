import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/controller/return_controller.dart';
import 'package:sahayi_android/model/invoice/doc_detail.dart';
import 'package:sahayi_android/model/return/customer.dart';

import '../../ui/ui.dart';

/// Finalize return (Version 2): summary, merged items, Finalize.
/// Same controller calls as Version 1: finalize(), then on success
/// getUnfinishedDocs(), update() and Get.close(3) back to Return start.
class FinalizeReturnScreen extends StatelessWidget {
  const FinalizeReturnScreen({super.key});

  static String formatDate(String? date) {
    if (date == null || date == 'null' || date.isEmpty) return '';
    try {
      final d = DateTime.parse(date);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final con = Get.find<ReturnController>();
    return Builder(builder: (context) {
      final c = context.c;
      final t = Theme.of(context).textTheme;

      Future<void> finalizeReturn() async {
        log(con.selectedCustomer.value.toString());
        final ok = await con.finalize();
        if (!ok) {
          AppToast.error('Not finalized', 'Something went wrong, try again.');
          return;
        }
        Get.dialog(
          PopScope(
            canPop: false,
            child: Builder(
                builder: (context) => AlertDialog(
                      icon: Icon(Icons.check_circle_rounded,
                          color: context.c.success, size: 48),
                      title: const Text('Return finalized'),
                      content: Text(
                        'The return of ${con.selectedCustomer.value.custName}, document ${con.docNumber.value}, '
                        'was sent to the server.',
                      ),
                      actions: [
                        AppButton(
                          label: 'Done',
                          onPressed: () {
                            con.selectedCustomer.value = Customer();
                            con.getUnfinishedDocs();
                            con.update();
                            Get.close(3);
                          },
                        ),
                      ],
                    )),
          ),
          barrierDismissible: false,
        );
      }

      void showDetails(DocDetail item) {
        final entries = con.savedItems
            .where((p) =>
                p.barcode == item.barcode &&
                p.reasonCode == item.reasonCode &&
                p.expiryDate == item.expiryDate)
            .map((e) => e.checkQty ?? 0)
            .toList();
        final total = entries.fold<int>(0, (a, b) => a + b);
        showModalBottomSheet(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(item.partName ?? '',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: Space.md),
                  KeyValueRow('Barcode', item.barcode),
                  KeyValueRow('Reason', item.reasonName),
                  if (item.expiryDate != null)
                    KeyValueRow('Expiry', formatDate(item.expiryDate)),
                  KeyValueRow('Entries', entries.join(' + ')),
                  KeyValueRow('Total', '$total'),
                  const SizedBox(height: Space.lg),
                  AppButton.secondary(
                      label: 'Close',
                      onPressed: () => Navigator.of(context).pop()),
                ]),
          ),
        );
      }

      return Obx(() {
        final loading = con.finalizeIsLoading.value;
        return PopScope(
          // Back is fine (nothing is lost) except while sending to the server.
          canPop: !loading,
          child: Scaffold(
            appBar: AppTopBar(
              title: 'Review return',
              badge: const DocTypeBadge('R'),
              onBack: loading ? () {} : null,
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(
                  Space.screen, Space.xs, Space.screen, Space.xl),
              children: [
                AppCard(
                  radius: Radii.lg,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: Space.sm),
                  child: Column(children: [
                    KeyValueRow('Customer',
                        '${con.selectedCustomer.value.custName ?? ''} · ${con.selectedCustomer.value.custId ?? ''}'),
                    KeyValueRow('Document', con.docNumber.value),
                    KeyValueRow('Date', con.docDate.value),
                    KeyValueRow('Returned by', con.driver.value?.name),
                  ]),
                ),
                SectionLabel(
                  'Items (merged)',
                  padding: const EdgeInsets.fromLTRB(
                      Space.xs, Space.lg, Space.xs, Space.sm),
                  trailing: Text('${con.consolidatedSavedItems.length}',
                      style: t.labelSmall),
                ),
                if (loading)
                  const Padding(
                      padding: EdgeInsets.all(Space.xxl),
                      child: Center(child: CircularProgressIndicator()))
                else
                  for (final (i, item) in con.consolidatedSavedItems.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: ItemCard(
                        leading: '${i + 1}',
                        title: item.partName ?? '',
                        subtitle: '${item.barcode ?? ''}'
                            '${item.expiryDate == null ? '' : ' · exp ${formatDate(item.expiryDate)}'}',
                        quantity: '${item.checkQty ?? 0}',
                        state: ItemState.done,
                        statusLabel: item.reasonCode ?? '',
                        trailing:
                            Icon(Icons.chevron_right_rounded, color: c.muted),
                        onTap: () => showDetails(item),
                      ),
                    ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                    Space.screen, Space.sm, Space.screen, Space.md),
                decoration: BoxDecoration(
                  color: c.background,
                  border: Border(top: BorderSide(color: c.divider)),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total quantity', style: t.bodySmall),
                          Text('${con.totalQty.value}',
                              style: t.headlineSmall?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ])),
                        ]),
                  ),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: 'Finalize',
                      icon: Icons.task_alt_rounded,
                      loading: loading,
                      onPressed: loading ? null : finalizeReturn,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      });
    });
  }
}
