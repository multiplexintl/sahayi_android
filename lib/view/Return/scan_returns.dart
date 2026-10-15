import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sahayi_android/controller/return_controller.dart';
import 'package:sahayi_android/db/db.dart';
import 'package:sahayi_android/model/invoice/doc_detail.dart';
import 'package:sahayi_android/model/return/reasons.dart';

import '../../ui/ui.dart';

/// Scan returns (Version 2). Same controller calls as Version 1:
/// onBarcodeChanged, onSavePart, clearPart, onDeleteItem, clearAll, onConfirm.
class ScanReturns extends StatelessWidget {
  const ScanReturns({super.key});

  static bool needsExpiry(Reasons? r) => r?.reasonId == 'NRE' || r?.reasonId == 'EXP';

  @override
  Widget build(BuildContext context) {
    final con = Get.find<ReturnController>();
    return V2Screen(
      child: Builder(builder: (context) {
        final c = context.c;
        final t = Theme.of(context).textTheme;

        Future<void> pickExpiry() async {
          final year = DateTime.now().year;
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(year - 1, 1, 1),
            lastDate: DateTime(year + 2, 12, 31),
            initialDate: DateTime.now(),
            helpText: 'Expiry date',
          );
          if (picked == null) return;
          final text = DateFormat('yyyy-MM-dd').format(picked); // format the controller expects
          con.expiryDateController.text = text;
          con.expiryDate.value = text;
          con.update();
        }

        Future<void> deleteItem(DocDetail item) async {
          final ok = await showConfirmSheet(
            context: context,
            title: 'Delete this item?',
            message: '${item.partName ?? item.barcode}\nQuantity ${item.checkQty} · Reason ${item.reasonCode}',
            confirmLabel: 'Delete',
            danger: true,
          );
          if (ok) await con.onDeleteItem(item.slNo!);
        }

        Future<void> deleteAll() async {
          final ok = await showConfirmSheet(
            context: context,
            title: 'Delete all items?',
            message: 'All ${con.savedItems.length} scanned items of this return are removed '
                'from this scanner. This cannot be undone.',
            confirmLabel: 'Delete all',
            danger: true,
          );
          if (ok) con.clearAll();
        }

        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Scaffold(
            appBar: AppTopBar(
              title: con.docNumber.value ?? 'Return',
              badge: const DocTypeBadge('R'),
              subtitle: '${con.selectedCustomer.value.custName ?? ''} · ${con.selectedCustomer.value.custId ?? ''}',
              actions: [
                if (kDebugMode)
                  IconButton(
                    tooltip: 'Developer: log saved rows',
                    icon: const Icon(Icons.build_circle_outlined),
                    onPressed: () async =>
                        log((await DBHelper.getAllItems(tableName: DBHelper.docDetail)).toString()),
                  ),
              ],
            ),
            body: CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.screen, Space.xs, Space.screen, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // Document summary
                    AppCard(
                      radius: Radii.lg,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Column(children: [
                        KeyValueRow('Date', con.docDate.value),
                        KeyValueRow('Returned by', con.driver.value?.name),
                      ]),
                    ),
                    const SizedBox(height: Space.md),
                    // Scan + quantity + reason (+ expiry)
                    AppCard(
                      child: GetBuilder<ReturnController>(builder: (_) {
                        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(
                              child: Obx(() => AppTextField(
                                    controller: con.barcodeController,
                                    focusNode: con.barcodeFocusNode,
                                    enabled: !con.scanIsLoading.value,
                                    hint: 'Scan barcode',
                                    prefixIcon: Icons.qr_code_scanner_rounded,
                                    onChanged: con.onBarcodeChanged,
                                  )),
                            ),
                            const SizedBox(width: Space.sm),
                            SizedBox(
                              width: 76,
                              child: Obx(() => AppTextField(
                                    controller: con.qtyController,
                                    focusNode: con.qtyFocusNode,
                                    enabled: !con.scanIsLoading.value,
                                    hint: 'Qty',
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                  )),
                            ),
                          ]),
                          Obx(() {
                            final part = con.selectedPart.value;
                            return Padding(
                              padding: const EdgeInsets.only(top: Space.sm, left: 2),
                              child: Row(children: [
                                Icon(Icons.inventory_2_outlined, size: 16, color: c.muted),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    part?.partName ?? 'Scan a barcode to find the item',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: part == null
                                        ? t.bodySmall
                                        : t.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: c.accentText),
                                  ),
                                ),
                              ]),
                            );
                          }),
                          const SizedBox(height: Space.md),
                          Obx(() => AppSelectField<Reasons>(
                                label: 'Reason',
                                placeholder: 'Select reason',
                                icon: Icons.rule_rounded,
                                value: con.selectedReason.value,
                                items: con.reasons,
                                itemLabel: (r) => '${r.reasonId} · ${r.reason}',
                                onChanged: (r) {
                                  con.selectedReason.value = r;
                                  con.update();
                                },
                              )),
                          if (needsExpiry(con.selectedReason.value)) ...[
                            const SizedBox(height: Space.md),
                            AppTextField(
                              label: 'Expiry date',
                              hint: 'Pick a date',
                              controller: con.expiryDateController,
                              readOnly: true,
                              onTap: pickExpiry,
                              prefixIcon: Icons.event_rounded,
                            ),
                          ],
                          const SizedBox(height: Space.lg),
                          Row(children: [
                            Expanded(child: AppButton.secondary(label: 'Clear fields', onPressed: con.clearPart)),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              flex: 2,
                              child: AppButton(
                                label: 'Save item',
                                icon: Icons.add_rounded,
                                onPressed: con.onSavePart,
                              ),
                            ),
                          ]),
                        ]);
                      }),
                    ),
                    Obx(() => SectionLabel(
                          'Scanned items',
                          padding: const EdgeInsets.fromLTRB(Space.xs, Space.lg, Space.xs, Space.sm),
                          trailing: Text('${con.savedItems.length}', style: t.labelSmall),
                        )),
                  ]),
                ),
              ),
              Obx(() => con.savedItems.isEmpty
                  ? const SliverToBoxAdapter(
                      child: EmptyState(title: 'No items yet', message: 'Scan the first returned item above.'),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.xl),
                      sliver: SliverList.separated(
                        itemCount: con.savedItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: Space.sm),
                        itemBuilder: (context, i) {
                          final item = con.savedItems[i];
                          return ItemCard(
                            leading: '${i + 1}',
                            title: item.partName ?? '',
                            subtitle: '${item.barcode ?? ''}'
                                '${item.expiryDate == null || item.expiryDate!.isEmpty ? '' : ' · exp ${item.expiryDate}'}',
                            quantity: '${item.checkQty ?? 0}',
                            state: ItemState.done,
                            statusLabel: item.reasonCode ?? '',
                            trailing: AppIconButton(
                              icon: Icons.delete_outline_rounded,
                              tooltip: 'Delete item',
                              color: c.dangerText,
                              size: 40,
                              onPressed: () => deleteItem(item),
                            ),
                          );
                        },
                      ),
                    )),
            ]),
            bottomNavigationBar: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.md),
                decoration: BoxDecoration(
                  color: c.background,
                  border: Border(top: BorderSide(color: c.divider)),
                ),
                child: Obx(() => Row(children: [
                      Expanded(
                        child: AppButton.danger(
                          label: 'Delete all',
                          icon: Icons.delete_sweep_outlined,
                          onPressed: con.savedItems.isEmpty ? null : deleteAll,
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          label: 'Review & confirm',
                          iconAfter: true,
                          icon: Icons.arrow_forward_rounded,
                          onPressed: con.onConfirm,
                        ),
                      ),
                    ])),
              ),
            ),
          ),
        );
      }),
    );
  }
}
