import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sahayi_android/controller/inv_trnf_controller.dart';
import 'package:sahayi_android/model/invoice/doc_detail.dart';

import '../../ui/ui.dart';

/// Scan invoice / transfer (Version 2).
///
/// Uses the controller exactly as Version 1 did: barcode typing ->
/// scrollToBarcode(), qty "go" -> saveQty(), Save validates first,
/// Clear -> clearInputFields(), Finalize -> finalize().
class ScanInvoiceScreen extends StatefulWidget {
  const ScanInvoiceScreen({super.key});

  @override
  State<ScanInvoiceScreen> createState() => _ScanInvoiceScreenState();
}

class _ScanInvoiceScreenState extends State<ScanInvoiceScreen> {
  final con = Get.find<InvoiceOrTransferController>();
  final _formKey = GlobalKey<FormState>();
  Worker? _scrollWorker;
  double _itemExtent = 76;

  /// List shows only lines that still need units (long invoices).
  bool _openOnly = false;

  List<DocDetail> _shown(List<DocDetail> items) => _openOnly
      ? items.where((i) => (i.checkQty ?? 0) < (i.shipQty ?? 0)).toList()
      : items;

  @override
  void initState() {
    super.initState();
    // The controller scrolls to the scanned item assuming 63 px rows. Our
    // cards are taller, so correct the position right after (a microtask
    // runs after the controller's own animateTo and replaces it).
    _scrollWorker = ever(con.scannedItem, (DocDetail item) {
      if (item.barcode == null) return;
      scheduleMicrotask(() => _scrollTo(item));
    });
  }

  @override
  void dispose() {
    _scrollWorker?.dispose();
    super.dispose();
  }

  /// Asks for an invoice line number and scrolls the list to it (shows all
  /// lines again if that line is hidden by "Open lines only").
  Future<void> _goToLine(List<DocDetail> items) async {
    final ctrl = TextEditingController();
    final number = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to line'),
        content: AppTextField(
          controller: ctrl,
          hint: 'Line number, e.g. 81',
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.go,
          onSubmitted: (v) => Navigator.of(context).pop(int.tryParse(v)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(int.tryParse(ctrl.text)),
              child: const Text('Go')),
        ],
      ),
    );
    // freed after the dialog has fully closed (see DeleteAllDialog)
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (number == null || !mounted) return;
    final line = items.firstWhereOrNull((i) => i.slNo == number);
    if (line == null) {
      final last =
          items.map((i) => i.slNo ?? 0).fold<int>(0, (a, b) => a > b ? a : b);
      AppToast.warning(
          'Line $number not found', 'The last line of this document is $last.');
      return;
    }
    if (_openOnly && !_shown(items).contains(line)) {
      setState(() => _openOnly = false);
      await WidgetsBinding.instance.endOfFrame;
    }
    _scrollTo(line);
  }

  /// "2 of 8 · " when this item is on several lines of the invoice (filled
  /// in order), otherwise empty.
  static String repeatLabel(List<DocDetail> items, DocDetail item) {
    if (item.barcode == null) return '';
    final same = items.where((i) => i.barcode == item.barcode).toList();
    if (same.length < 2) return '';
    return '${same.indexOf(item) + 1} of ${same.length} · ';
  }

  /// Scrolls to that exact line (the same item can be on several lines).
  void _scrollTo(DocDetail line) {
    final items = _shown(con.docMaster.value.docDetails ?? const <DocDetail>[]);
    final index = items
        .indexWhere((i) => i.slNo == line.slNo && i.barcode == line.barcode);
    final sc = con.scrollController;
    if (index < 0 || !sc.hasClients) return;
    final target =
        (index * _itemExtent).clamp(0.0, sc.position.maxScrollExtent);
    sc.animateTo(target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic);
  }

  static String _formatDocDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      return DateFormat('dd/MM/yyyy')
          .format(DateFormat('M/d/yyyy h:mm:ss a').parse(raw));
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) {
      final c = context.c;
      final t = Theme.of(context).textTheme;
      // Fixed card height (grows with the system font size) so scrolling
      // to an item is exact.
      _itemExtent = 32 + MediaQuery.textScalerOf(context).scale(44);

      return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Obx(() {
          final doc = con.docMaster.value;
          final isInvoice = con.isInvoice.value;
          final items = doc.docDetails ?? const <DocDetail>[];
          final done = items.where((i) => i.checkQty == i.shipQty).length;
          final left = items.length - done;
          final unitsLeft = items.fold<int>(
              0,
              (s, i) =>
                  s + ((i.shipQty ?? 0) - (i.checkQty ?? 0)).clamp(0, 1 << 30));
          final shown = _shown(items);
          final busy = con.scanIsLoading.value;
          final selected = con.scannedItem.value;
          final dateText = _formatDocDate(doc.docDate);

          return Scaffold(
            appBar: AppTopBar(
              title: doc.docNum ?? (isInvoice ? 'Invoice' : 'Transfer'),
              badge: DocTypeBadge(isInvoice ? 'I' : 'T'),
              subtitle: [doc.custName, dateText]
                  .where((s) => s != null && s.isNotEmpty)
                  .join(' · '),
              actions: [
                if (doc.docNum != null)
                  _ListMenu(
                    openOnly: _openOnly,
                    onOpenOnly: (v) => setState(() => _openOnly = v),
                    onGoToLine: () => _goToLine(items),
                  ),
                if (kDebugMode) _DeveloperMenu(con: con),
              ],
            ),
            body: doc.docNum == null
                ? EmptyState(
                    title: 'Nothing to scan',
                    message:
                        'Sync a ${isInvoice ? 'invoice' : 'transfer'} first.',
                  )
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Space.screen, Space.xs, Space.screen, Space.sm),
                      child: ProgressCard(
                          done: done,
                          total: items.length,
                          unit: 'lines',
                          detail:
                              unitsLeft > 0 ? '$unitsLeft units left' : null),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: Space.screen),
                      child: Form(
                        key: _formKey,
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: con.barcodeController,
                                  focusNode: con.barcodeFocusNode,
                                  enabled: !busy,
                                  hint: 'Scan barcode',
                                  prefixIcon: Icons.qr_code_scanner_rounded,
                                  onChanged: con.scrollToBarcode,
                                  keyboardType: TextInputType.visiblePassword,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Scan a barcode';
                                    }
                                    if (v.length < 10 || v.length > 14) {
                                      return '10–14 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: Space.sm),
                              SizedBox(
                                width: 68,
                                child: AppTextField(
                                  controller: con.qtyController,
                                  focusNode: con.qtyFocusNode,
                                  enabled: !busy,
                                  hint: 'Qty',
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  // onEditingComplete: con.saveQty,
                                  onEditingComplete: busy
                                      ? null
                                      : () {
                                          if (_formKey.currentState
                                                  ?.validate() ==
                                              true) {
                                            con.saveQty();
                                          }
                                        },
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Qty'
                                          : null,
                                  style: t.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                  additionalDecoration: InputDecoration(
                                    contentPadding: EdgeInsets.only(
                                      left: 5,
                                      right: 5,
                                      top: 11,
                                      bottom: 11,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: Space.sm),
                              SizedBox(
                                width: 52,
                                child: AppButton(
                                  label: '',
                                  icon: Icons.check_rounded,
                                  loading: busy,
                                  onPressed: busy
                                      ? null
                                      : () {
                                          if (_formKey.currentState
                                                  ?.validate() ==
                                              true) {
                                            con.saveQty();
                                          }
                                        },
                                ),
                              ),
                            ]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Space.lg, Space.sm, Space.lg, 0),
                      child: Row(children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 16, color: c.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            selected.partName ??
                                'Scan a barcode to pick an item',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: selected.partName == null
                                ? t.bodySmall
                                : t.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: c.accentText),
                          ),
                        ),
                      ]),
                    ),
                    SectionLabel('Items',
                        trailing: Text(_openOnly
                            ? 'Open lines only · ${shown.length}'
                            : 'Checked / Shipped')),
                    Expanded(
                      child:
                          GetBuilder<InvoiceOrTransferController>(builder: (_) {
                        return ListView.builder(
                          controller: con.scrollController,
                          itemExtent: _itemExtent,
                          padding: const EdgeInsets.fromLTRB(
                              Space.screen, 0, Space.screen, 120),
                          itemCount: shown.length,
                          itemBuilder: (context, index) {
                            final item = shown[index];
                            final ship = item.shipQty ?? 0;
                            final check = item.checkQty ?? 0;
                            // the exact line being filled, not every line of that item
                            final state = item.barcode != null &&
                                    item.barcode == selected.barcode &&
                                    item.slNo == selected.slNo
                                ? ItemState.active
                                : check == ship
                                    ? ItemState.done
                                    : check > 0
                                        ? ItemState.partial
                                        : ItemState.todo;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: Space.sm),
                              child: ItemCard(
                                // invoice line number, to compare with the paper invoice
                                leading: '${item.slNo ?? index + 1}',
                                title: item.partName ?? '',
                                titleMaxLines: 1,
                                subtitle:
                                    '${repeatLabel(items, item)}${item.partNum ?? ''} · ${item.barcode ?? ''}',
                                quantity: '$check / $ship',
                                state: state,
                                // Debug builds only (guarded in the controller): pre-fill this item.
                                onTap: kDebugMode
                                    ? () => con.testSave(item.barcode!, ship)
                                    : null,
                              ),
                            );
                          },
                        );
                      }),
                    ),
                  ]),
            bottomNavigationBar: doc.docNum == null
                ? null
                : SafeArea(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(
                          Space.screen, Space.sm, Space.screen, Space.md),
                      decoration: BoxDecoration(
                        color: c.background,
                        border: Border(top: BorderSide(color: c.divider)),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: AppButton.secondary(
                            label: 'Clear',
                            onPressed: busy ? null : con.clearInputFields,
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          flex: 2,
                          child: Obx(() => AppButton(
                                label: 'Finalize',
                                icon: Icons.task_alt_rounded,
                                disabledLabel: left > 0
                                    ? 'Finalize · $left ${left == 1 ? 'line' : 'lines'} left'
                                    : null,
                                loading: busy && con.isFinalize.value,
                                onPressed: busy || !con.isFinalize.value
                                    ? null
                                    : con.finalize,
                              )),
                        ),
                      ]),
                    ),
                  ),
          );
        }),
      );
    });
  }
}

/// Debug builds only: the developer shortcuts that used to be hidden gestures.
/// ⋮ menu: show only open lines, jump to an invoice line number.
class _ListMenu extends StatelessWidget {
  final bool openOnly;
  final ValueChanged<bool> onOpenOnly;
  final VoidCallback onGoToLine;
  const _ListMenu(
      {required this.openOnly,
      required this.onOpenOnly,
      required this.onGoToLine});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'List options',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (v) => v == 'open' ? onOpenOnly(!openOnly) : onGoToLine(),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
            value: 'open',
            checked: openOnly,
            child: const Text('Open lines only')),
        const PopupMenuItem(value: 'goto', child: Text('Go to line…')),
      ],
    );
  }
}

class _DeveloperMenu extends StatelessWidget {
  final InvoiceOrTransferController con;
  const _DeveloperMenu({required this.con});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Developer tools',
      icon: const Icon(Icons.build_circle_outlined),
      onSelected: (v) => v == 'fill' ? con.fillAllDebug() : con.clearAllDebug(),
      itemBuilder: (_) => const [
        PopupMenuItem(
            value: 'fill', child: Text('Developer: mark all checked')),
        PopupMenuItem(value: 'clear', child: Text('Developer: reset all to 0')),
      ],
    );
  }
}
