import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sahayi_android/controller/return_controller.dart';
import 'package:sahayi_android/db/db.dart';
import 'package:sahayi_android/model/company.dart';
import 'package:sahayi_android/model/invoice/doc_master.dart';
import 'package:sahayi_android/model/pickers/pickers.dart';
import 'package:sahayi_android/model/return/customer.dart';

import '../../ui/ui.dart';

/// Return start (Version 2): new-return form + unfinished returns.
/// Same controller calls as Version 1: onSubmit(null) starts, onSubmit(doc)
/// resumes, removeUnfinished(doc) deletes, clearCustSelction() clears.
class CustomerSelectScreen extends StatelessWidget {
  const CustomerSelectScreen({super.key});

  static final _dateFormat =
      DateFormat('dd-MM-yyyy'); // format the controller expects

  @override
  Widget build(BuildContext context) {
    final con = Get.find<ReturnController>();
    return Builder(builder: (context) {
      final c = context.c;
      final t = Theme.of(context).textTheme;

      Future<void> pickDate() async {
        final today = DateTime.now();
        final max = DateTime(today.year, today.month, today.day);
        DateTime? initial;
        try {
          initial = con.docDateController.text.isEmpty
              ? null
              : _dateFormat.parse(con.docDateController.text);
        } catch (_) {}
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(today.year - 2, today.month, today.day),
          lastDate: max,
          initialDate: initial ?? max,
          helpText: 'Document date',
        );
        if (picked == null) return;
        final text = _dateFormat.format(picked);
        con.docDateController.text = text;
        con.docDate.value = text;
        con.update();
      }

      Future<void> deleteUnfinished(DocMaster doc) async {
        final ok = await showConfirmSheet(
          context: context,
          title: 'Delete this unfinished return?',
          message: '${doc.custID} · ${doc.custName}\nDocument ${doc.docNum}\n\n'
              'Its scanned items are removed from this scanner.',
          confirmLabel: 'Delete',
          danger: true,
        );
        if (ok) await con.removeUnfinished(doc);
      }

      return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          appBar: AppTopBar(
            title: 'New return',
            badge: DocTypeBadge('R'),
            actions: [if (kDebugMode) _DeveloperMenu(con: con)],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
                Space.screen, Space.xs, Space.screen, Space.xl),
            children: [
              AppCard(
                child: GetBuilder<ReturnController>(builder: (_) {
                  return Obx(() {
                    final hasCompany = con.selectedCompany.value != null;
                    final busy = con.selectIsLoading.value;
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppSelectField<Company>(
                            label: 'Company',
                            placeholder: 'Select company',
                            icon: Icons.business_rounded,
                            value: con.selectedCompany.value,
                            items: con.companyList,
                            itemLabel: (co) =>
                                co.companyName ?? co.companyId ?? '',
                            itemSubtitle: (co) => co.companyId,
                            enabled: !con.syncIsLoading.value,
                            onChanged: con.syncIsLoading.value
                                ? null
                                : con.selectComapny,
                          ),
                          const SizedBox(height: Space.md),
                          _CustomerField(con: con, enabled: hasCompany),
                          const SizedBox(height: Space.md),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: 'Document no.',
                                    hint: 'e.g. 2025-37088',
                                    controller: con.docNumController,
                                    enabled: hasCompany,
                                  ),
                                ),
                                const SizedBox(width: Space.sm),
                                Expanded(
                                  child: AppTextField(
                                    label: 'Date',
                                    hint: 'dd-mm-yyyy',
                                    controller: con.docDateController,
                                    enabled: hasCompany,
                                    readOnly: true,
                                    onTap: pickDate,
                                    additionalDecoration: InputDecoration(
                                        suffix: const Icon(
                                            Icons.calendar_today_rounded,
                                            size: 18),
                                        contentPadding: EdgeInsets.only(
                                          left: 5,
                                          right: 5,
                                          top: 13,
                                          bottom: 13,
                                        )),
                                  ),
                                ),
                              ]),
                          const SizedBox(height: Space.md),
                          AppSelectField<Pickers>(
                            label: 'Returned by (driver / helper)',
                            placeholder: 'Select driver',
                            icon: Icons.local_shipping_outlined,
                            value: con.selectedDriver.value,
                            items: con.driverList,
                            itemLabel: (p) => p.name ?? '',
                            itemSubtitle: (p) => p.id,
                            enabled: hasCompany && !busy,
                            onChanged:
                                hasCompany && !busy ? con.selectDriver : null,
                          ),
                          const SizedBox(height: Space.lg),
                          Row(children: [
                            Expanded(
                              child: AppButton.secondary(
                                  label: 'Clear',
                                  onPressed: con.clearCustSelction),
                            ),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              flex: 2,
                              child: AppButton(
                                label: 'Start return',
                                icon: Icons.arrow_forward_rounded,
                                iconAfter: true,
                                loading: busy,
                                onPressed:
                                    busy ? null : () => con.onSubmit(null),
                              ),
                            ),
                          ]),
                        ]);
                  });
                }),
              ),
              Obx(() => SectionLabel(
                    'Unfinished returns',
                    padding: const EdgeInsets.fromLTRB(
                        Space.xs, Space.xl, Space.xs, Space.sm),
                    trailing: StatusChip(
                      kind: con.unFinishedDocs.isEmpty
                          ? StatusKind.neutral
                          : StatusKind.warning,
                      label: '${con.unFinishedDocs.length}',
                      small: true,
                    ),
                  )),
              Obx(() {
                if (con.unFinishedDocs.isEmpty) {
                  return const EmptyState(
                    title: 'All caught up',
                    message: 'No unfinished returns on this scanner.',
                  );
                }
                return Column(children: [
                  for (final doc in con.unFinishedDocs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: AppCard(
                        radius: Radii.lg,
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${doc.custName ?? ''} · ${doc.custID ?? ''}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text('Doc ${doc.docNum ?? ''}',
                                      style: t.bodySmall),
                                ]),
                          ),
                          AppIconButton(
                            icon: Icons.delete_outline_rounded,
                            tooltip: 'Delete unfinished return',
                            color: c.dangerText,
                            background: c.dangerSoft,
                            size: 40,
                            onPressed: () => deleteUnfinished(doc),
                          ),
                          const SizedBox(width: Space.sm),
                          SizedBox(
                            height: 40,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: c.primarySoft,
                                foregroundColor: c.onPrimarySoft,
                                minimumSize: const Size(0, 40),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: Radii.all(Radii.md)),
                              ),
                              onPressed: () => con.onSubmit(doc),
                              child: const Text('Resume'),
                            ),
                          ),
                        ]),
                      ),
                    ),
                ]);
              }),
            ],
          ),
        ),
      );
    });
  }
}

/// Looks like a field; tap opens a sheet that searches customers on the server
/// as you type (con.getSuggestions), then calls con.onCustomerSelected.
class _CustomerField extends StatelessWidget {
  final ReturnController con;
  final bool enabled;
  const _CustomerField({required this.con, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: con.custController,
      builder: (context, value, _) => AppTextField(
        label: 'Customer',
        hint: enabled ? 'Search customer' : 'Select company first',
        controller: con.custController,
        enabled: enabled,
        readOnly: true,
        prefixIcon: Icons.search_rounded,
        onTap: () async {
          final picked = await showModalBottomSheet<Customer>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => _CustomerSearchSheet(con: con),
          );
          if (picked != null) con.onCustomerSelected(picked);
        },
      ),
    );
  }
}

class _CustomerSearchSheet extends StatefulWidget {
  final ReturnController con;
  const _CustomerSearchSheet({required this.con});

  @override
  State<_CustomerSearchSheet> createState() => _CustomerSearchSheetState();
}

class _CustomerSearchSheetState extends State<_CustomerSearchSheet> {
  Timer? _debounce;
  List<Customer> _results = const [];
  bool _loading = false;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _query = q;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (q.trim().isEmpty) {
        setState(() => _results = const []);
        return;
      }
      setState(() => _loading = true);
      final res = await widget.con.getSuggestions(q);
      if (!mounted || q != _query) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.md),
            child: Text('Customer', style: t.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: TextField(
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Customer ID or name',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                        _query.trim().isEmpty
                            ? 'Type to search'
                            : (_loading ? '' : 'No customers found'),
                        style: t.bodySmall),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        Space.sm, Space.sm, Space.sm, Space.lg),
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final cust = _results[i];
                      return ListTile(
                        leading: const Icon(Icons.storefront_outlined),
                        title: Text(cust.custName ?? ''),
                        subtitle: Text(cust.custId ?? ''),
                        onTap: () => Navigator.of(context).pop(cust),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Debug builds only: replaces the hidden long-press on Submit.
class _DeveloperMenu extends StatelessWidget {
  final ReturnController con;
  const _DeveloperMenu({required this.con});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Developer tools',
        icon: const Icon(Icons.build_circle_outlined),
        onSelected: (value) async {
          if (value == 'list') {
            con.getPickers();
          }
          if (value == 'cols') {
            await DBHelper.listColumnsInTable(DBHelper.docMaster);
            await DBHelper.listColumnsInTable(DBHelper.docDetail);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'cols',
            child: Text('Developer: log table columns'),
          ),
          PopupMenuItem(
            value: 'list',
            child: Text('Developer: get driver list'),
          ),
        ],
      );
}
