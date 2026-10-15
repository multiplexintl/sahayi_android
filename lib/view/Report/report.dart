import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sahayi_android/controller/home_controller.dart';
import 'package:sahayi_android/controller/report_controller.dart';
import 'package:sahayi_android/model/report/report.dart';

import '../../ui/ui.dart';

/// Report (Version 2): filters card + result cards. Same controller calls as
/// Version 1: updateDate, clearDates, fetchReport, filterReports, selectReport.
class ReportViewPage extends StatelessWidget {
  const ReportViewPage({super.key});

  static final _dateFormat = DateFormat('dd-MM-yyyy'); // format the controller uses

  @override
  Widget build(BuildContext context) {
    final con = Get.put(ReportController());
    final user = Get.find<HomeController>().user.value;
    return V2Screen(
      child: Builder(builder: (context) {
        final c = context.c;
        final t = Theme.of(context).textTheme;

        Future<void> pickDate({required bool isFrom}) async {
          final today = DateTime.now();
          final ctrl = isFrom ? con.fromDateController.value : con.toDateController.value;
          DateTime? initial;
          try {
            initial = ctrl.text.isEmpty ? null : _dateFormat.parse(ctrl.text);
          } catch (_) {}
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(today.year - 32, today.month, today.day),
            lastDate: today,
            initialDate: initial ?? today,
            helpText: isFrom ? 'From date' : 'To date',
          );
          if (picked != null) con.updateDate(date: picked, isFrom: isFrom);
        }

        // "All" first, then Invoice / Transfer / Return.
        final types = [
          ...con.reportTypes.where((m) => m.keys.first == 'A'),
          ...con.reportTypes.where((m) => m.keys.first != 'A'),
        ];

        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Scaffold(
            appBar: AppTopBar(title: 'Report', subtitle: user.empName),
            body: CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.screen, Space.xs, Space.screen, 0),
                sliver: SliverToBoxAdapter(
                  child: AppCard(
                    child: Obx(() {
                      final busy = con.isLoading.value;
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('Document type', style: t.labelMedium),
                        const SizedBox(height: Space.xs + 2),
                        Wrap(spacing: Space.sm, runSpacing: Space.xs, children: [
                          for (final type in types)
                            ChoiceChip(
                              label: Text(type.values.first.toString()),
                              selected: con.selectedType.value?.keys.first == type.keys.first,
                              onSelected: busy ? null : (_) => con.selectedType.value = type,
                            ),
                        ]),
                        const SizedBox(height: Space.md),
                        Row(children: [
                          Expanded(
                            child: AppTextField(
                              label: 'From',
                              controller: con.fromDateController.value,
                              readOnly: true,
                              enabled: !busy,
                              onTap: () => pickDate(isFrom: true),
                              suffix: const Icon(Icons.calendar_today_rounded, size: 18),
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: AppTextField(
                              label: 'To',
                              controller: con.toDateController.value,
                              readOnly: true,
                              enabled: !busy,
                              onTap: () => pickDate(isFrom: false),
                              suffix: const Icon(Icons.calendar_today_rounded, size: 18),
                            ),
                          ),
                        ]),
                        const SizedBox(height: Space.xs),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text('All companies', style: t.bodyMedium),
                          subtitle: Text('Off: only ${user.company ?? 'your company'}', style: t.bodySmall),
                          value: con.fetchAll.value,
                          onChanged: busy ? null : (v) => con.fetchAll.value = v,
                        ),
                        const SizedBox(height: Space.sm),
                        Row(children: [
                          Expanded(child: AppButton.secondary(label: 'Clear', onPressed: busy ? null : con.clearDates)),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            flex: 2,
                            child: AppButton(
                              label: 'Show report',
                              icon: Icons.search_rounded,
                              loading: busy,
                              onPressed: busy
                                  ? null
                                  : () {
                                      FocusManager.instance.primaryFocus?.unfocus();
                                      con.fetchReport();
                                    },
                            ),
                          ),
                        ]),
                      ]);
                    }),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Obx(() => con.reports.isEmpty
                    ? const SizedBox(height: Space.md)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(Space.screen, Space.lg, Space.screen, Space.sm),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          AppTextField(
                            controller: con.searchController,
                            hint: 'Filter by document number',
                            prefixIcon: Icons.filter_list_rounded,
                            onChanged: con.filterReports,
                          ),
                          const SizedBox(height: Space.sm),
                          Text('${con.filteredReports.length} of ${con.reports.length} documents',
                              style: t.labelSmall),
                        ]),
                      )),
              ),
              Obx(() {
                if (con.reports.isEmpty) {
                  return SliverToBoxAdapter(
                    child: con.isLoading.value
                        ? const SizedBox.shrink()
                        : const EmptyState(
                            title: 'No report yet',
                            message: 'Pick a type and dates, then tap Show report.',
                          ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.xl),
                  sliver: SliverList.separated(
                    itemCount: con.filteredReports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Space.sm),
                    itemBuilder: (context, i) => _ReportCard(
                      report: con.filteredReports[i],
                      onTap: () => con.selectReport(con.filteredReports[i]),
                      muted: c.muted,
                    ),
                  ),
                );
              }),
            ]),
          ),
        );
      }),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback onTap;
  final Color muted;
  const _ReportCard({required this.report, required this.onTap, required this.muted});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      radius: Radii.lg,
      padding: const EdgeInsets.fromLTRB(14, Space.md, Space.sm, Space.md),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              DocTypeBadge(report.docType),
              const SizedBox(width: Space.sm),
              Flexible(
                child: Text(report.docNum ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ]),
            const SizedBox(height: 4),
            Text('${report.custName ?? ''} · ${report.custId ?? ''}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyMedium),
            const SizedBox(height: 2),
            Text('${report.company ?? ''} · ${report.scanTime ?? ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: muted),
      ]),
    );
  }
}
