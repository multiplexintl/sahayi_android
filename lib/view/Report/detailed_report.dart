import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/controller/report_controller.dart';
import 'package:sahayi_android/model/invoice/doc_detail.dart';

import '../../ui/ui.dart';

/// Report details (Version 2): document summary + its lines.
/// The barcode search now FILTERS the lines (Version 1 scrolled to them).
class DetailedReportPage extends StatefulWidget {
  const DetailedReportPage({super.key});

  @override
  State<DetailedReportPage> createState() => _DetailedReportPageState();
}

class _DetailedReportPageState extends State<DetailedReportPage> {
  final con = Get.find<ReportController>();
  final _search = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() => setState(() {
        _searching = !_searching;
        if (!_searching) {
          _search.clear();
          _query = '';
        }
      });

  static String title(String? docType) => switch (docType) {
        'R' => 'Return report',
        'I' => 'Invoice report',
        _ => 'Transfer report',
      };

  void _showLine(BuildContext context, DocDetail item, int no) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(item.partName ?? '', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.md),
          KeyValueRow('Line', '$no'),
          KeyValueRow('Part no.', item.partNum),
          KeyValueRow('Brand', item.brand),
          KeyValueRow('Barcode', item.barcode),
          KeyValueRow('Quantity', '${item.checkQty ?? 0}'),
          if ((item.reasonCode ?? '').isNotEmpty) KeyValueRow('Reason', '${item.reasonCode} · ${item.reasonName ?? ''}'),
          if (item.docType == 'R' && (item.reasonCode == 'NRE' || item.reasonCode == 'EXP'))
            KeyValueRow('Expiry date', item.expiryDate),
          const SizedBox(height: Space.lg),
          AppButton.secondary(label: 'Close', onPressed: () => Navigator.of(context).pop()),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return V2Screen(
      child: Builder(builder: (context) {
        final t = Theme.of(context).textTheme;
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Obx(() {
            final doc = con.detailedReport.value;
            return Scaffold(
              appBar: AppTopBar(
                title: doc?.docNum ?? 'Report',
                badge: doc == null ? null : DocTypeBadge(doc.docType),
                subtitle: doc == null ? null : title(doc.docType),
                actions: [
                  if (doc != null)
                    AppIconButton(
                      icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                      tooltip: _searching ? 'Close search' : 'Find a barcode',
                      onPressed: _toggleSearch,
                    ),
                ],
              ),
              body: con.isLoadingDetailed.value
                  ? const Center(child: CircularProgressIndicator())
                  : doc == null
                      ? const EmptyState(title: 'No details found', message: 'Please go back and try again.')
                      : Builder(builder: (context) {
                          final all = doc.docDetails ?? const <DocDetail>[];
                          final q = _query.trim().toLowerCase();
                          final shown = q.isEmpty
                              ? all
                              : all.where((i) => (i.barcode ?? '').toLowerCase().contains(q)).toList();
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(Space.screen, Space.xs, Space.screen, Space.xl),
                            children: [
                              if (_searching) ...[
                                AppTextField(
                                  controller: _search,
                                  autofocus: true,
                                  hint: 'Scan or type a barcode',
                                  prefixIcon: Icons.qr_code_scanner_rounded,
                                  onChanged: (v) => setState(() => _query = v),
                                ),
                                const SizedBox(height: Space.md),
                              ],
                              AppCard(
                                radius: Radii.lg,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.sm),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                                    child: doc.stat == 'D'
                                        ? const StatusChip.progress('Downloaded')
                                        : const StatusChip.done('Completed'),
                                  ),
                                  KeyValueRow('Company', doc.company),
                                  KeyValueRow('Doc date', doc.docDate),
                                  KeyValueRow('Customer', '${doc.custName ?? ''} · ${doc.custID ?? ''}'),
                                  KeyValueRow('Scan time', doc.scanTime),
                                  KeyValueRow('Scanned by', doc.userId),
                                  KeyValueRow(doc.docType == 'R' ? 'Returned by' : 'Picked by', doc.pickedBy),
                                ]),
                              ),
                              SectionLabel(
                                'Items',
                                padding: const EdgeInsets.fromLTRB(Space.xs, Space.lg, Space.xs, Space.sm),
                                trailing: Text(
                                    q.isEmpty ? '${all.length}' : '${shown.length} of ${all.length}',
                                    style: t.labelSmall),
                              ),
                              if (shown.isEmpty)
                                EmptyState(title: 'No line with barcode "$_query"', image: 'assets/images/helper_1.png')
                              else
                                for (final item in shown)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: Space.sm),
                                    child: ItemCard(
                                      leading: '${all.indexOf(item) + 1}',
                                      title: item.partName ?? '',
                                      subtitle: '${item.partNum ?? ''} · ${item.barcode ?? ''}',
                                      quantity: '${item.checkQty ?? 0}',
                                      state: ItemState.plain,
                                      statusLabel: item.reasonCode,
                                      onTap: () => _showLine(context, item, all.indexOf(item) + 1),
                                    ),
                                  ),
                            ],
                          );
                        }),
            );
          }),
        );
      }),
    );
  }
}
