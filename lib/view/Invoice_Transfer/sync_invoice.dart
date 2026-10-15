import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/controller/inv_trnf_controller.dart';
import 'package:sahayi_android/model/company.dart';
import 'package:sahayi_android/model/pickers/pickers.dart';

import '../../ui/ui.dart';

/// Sync invoice / transfer (Version 2). Same actions as before:
/// checkValidation() downloads the document, clearInvoiceDB() deletes local data.
class SyncInvoiceScreen extends StatelessWidget {
  const SyncInvoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final con = Get.find<InvoiceOrTransferController>();
    return Builder(builder: (context) {
      final c = context.c;
      final t = Theme.of(context).textTheme;
      final isInvoice = con.isInvoice.value;
      final noun = isInvoice ? 'invoice' : 'transfer';
      return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          appBar: AppTopBar(
            title: 'Sync $noun',
            badge: DocTypeBadge(isInvoice ? 'I' : 'T'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(Space.screen, Space.xs, Space.screen, Space.xl),
            children: [
              AppCard(
                child: Obx(() {
                  final busy = con.syncIsLoading.value;
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    AppSelectField<Company>(
                      label: 'Company',
                      placeholder: 'Select company',
                      icon: Icons.business_rounded,
                      value: con.selectedCompany.value,
                      items: con.companyList,
                      itemLabel: (co) => co.companyName ?? co.companyId ?? '',
                      itemSubtitle: (co) => co.companyId,
                      enabled: !busy,
                      onChanged: busy ? null : con.selectComapny,
                    ),
                    const SizedBox(height: Space.md),
                    AppTextField(
                      label: isInvoice ? 'Invoice number' : 'Shipment number',
                      hint: isInvoice ? 'e.g. 25032700' : 'e.g. 2025-39691',
                      controller: con.invController,
                      enabled: !busy,
                      prefixIcon: Icons.tag_rounded,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      suffix: IconButton(
                        tooltip: 'Clear number',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: busy ? null : con.invController.clear,
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    AppSelectField<Pickers>(
                      label: 'Picker',
                      placeholder: 'Select picker',
                      icon: Icons.person_rounded,
                      value: con.selectedPicker.value,
                      items: con.pickerList,
                      itemLabel: (p) => p.name ?? '',
                      itemSubtitle: (p) => p.id,
                      enabled: !busy,
                      onChanged: busy ? null : con.selectPicker,
                    ),
                    const SizedBox(height: Space.lg),
                    AppButton(
                      label: 'Sync $noun from server',
                      icon: Icons.cloud_download_rounded,
                      loading: busy,
                      onPressed: busy ? null : con.checkValidation,
                    ),
                  ]);
                }),
              ),

              // Danger zone: clearly separated from the main action.
              Padding(
                padding: const EdgeInsets.only(top: Space.xxl),
                child: AppCard(
                  shadow: false,
                  color: c.surface,
                  borderColor: c.dangerBorder,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Icon(Icons.warning_amber_rounded, color: c.dangerText, size: Sizes.iconSm + 2),
                      const SizedBox(width: Space.sm),
                      Text('Danger zone', style: t.titleSmall?.copyWith(color: c.dangerText)),
                    ]),
                    const SizedBox(height: Space.xs),
                    Text(
                      'Removes all downloaded ${noun}s and the recent list from this scanner. '
                      'Unfinished work is lost.',
                      style: t.bodySmall,
                    ),
                    const SizedBox(height: Space.md),
                    Obx(() => AppButton.danger(
                          label: 'Delete local data',
                          icon: Icons.delete_outline_rounded,
                          loading: con.clearIsLoading.value,
                          onPressed: con.clearIsLoading.value || con.syncIsLoading.value ? null : con.clearInvoiceDB,
                        )),
                  ]),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
