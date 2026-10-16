import 'package:flutter/material.dart';
import 'package:sahayi_android/ui/ui.dart';
import 'package:get/get.dart';
import 'package:global_configuration/global_configuration.dart';

import '../../controller/admin/device_logs_controller.dart';
import '../../model/app_log.dart';
import '../../service/app_logger.dart';
import '../../service/log_uploader.dart';
import 'log_widgets.dart';

/// "This device" tab: status, filters and the logs stored on this scanner.
/// Laid out for small screens: one-line summary (expandable), one-line filter
/// bar, one row of quick filters, then the list.
class DeviceLogsTab extends StatefulWidget {
  const DeviceLogsTab({super.key});

  @override
  State<DeviceLogsTab> createState() => _DeviceLogsTabState();
}

class _DeviceLogsTabState extends State<DeviceLogsTab>
    with AutomaticKeepAliveClientMixin {
  static const _tag = 'deviceLogs';
  DeviceLogsController? _con;
  final _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true; // keep list and filters when switching tabs

  @override
  void initState() {
    super.initState();
    final db = AppLogger.db;
    if (db != null) _con = Get.put(DeviceLogsController(db), tag: _tag);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _con?.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    Get.delete<DeviceLogsController>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final con = _con;
    if (con == null) {
      return const Center(child: Text('Logs are not available on this device.'));
    }

    return Column(
      children: [
        _StatusBar(con: con),
        Obx(() => FilterBar(
              search: con.searchController,
              onSearchChanged: con.onSearchChanged,
              onClearSearch: con.clearSearch,
              filter: con.filter.value,
              onDates: con.setDates,
              onMoreFilters: () async {
                final f = await FilterSheet.show(context,
                    initial: con.filter.value, valuesOf: con.valuesOf);
                if (f != null) con.setFilter(f);
              },
            )),
        Obx(() => ActiveDatesLine(
            filter: con.filter.value, onClear: () => con.setDates(null, null))),
        Obx(() => PresetChips(filter: con.filter.value, onSelected: con.setPreset)),
        const Divider(height: 8),
        Expanded(
          child: Obx(() {
            if (con.loading.value && con.logs.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (con.logs.isEmpty) {
              return const Center(child: Text('No logs match these filters.'));
            }
            return RefreshIndicator(
              onRefresh: con.refreshAll,
              child: ListView.separated(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: con.logs.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == con.logs.length) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: con.hasMore.value
                            ? const CircularProgressIndicator()
                            : Text('${con.logs.length} shown · end of list',
                                style: Theme.of(context).textTheme.labelSmall),
                      ),
                    );
                  }
                  return _LogTile(log: con.logs[i]);
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// One line: counts + Upload + Clear + expand. Expanded: upload/device details.
class _StatusBar extends StatelessWidget {
  final DeviceLogsController con;
  const _StatusBar({required this.con});

  Future<void> _confirmClear({required bool onlySent}) async {
    final waiting = con.stats.value?.waiting ?? 0;
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text(onlySent ? 'Clear sent logs?' : 'Clear ALL logs on this device?'),
      content: Text(onlySent
          ? 'Logs already on the server are removed from this device. '
              'Logs still waiting to upload are kept.'
          : (waiting > 0
              ? '$waiting logs have NOT reached the server yet and will be lost. This cannot be undone.'
              : 'All logs on this device are removed. They are already on the server.')),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Get.context!.c.dangerSoft, foregroundColor: Get.context!.c.dangerText),
          onPressed: () => Get.back(result: true),
          child: const Text('Clear'),
        ),
      ],
    ));
    if (ok != true) return;
    final removed = await con.clear(onlySent: onlySent);
    Get.snackbar('Cleared', '$removed logs removed from this device',
        snackPosition: SnackPosition.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Obx(() {
        final s = con.stats.value;
        final expanded = con.statusExpanded.value;
        final paused = LogUploader.pausedUntil;
        final last = LogUploader.lastSuccessAt;
        final waiting = s?.waiting ?? 0;
        final rejected = s?.rejected ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => con.statusExpanded.toggle(),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(style: small, children: [
                        TextSpan(text: '${s?.total ?? 0} logs'),
                        const TextSpan(text: ' · '),
                        TextSpan(
                            text: '$waiting waiting',
                            style: TextStyle(color: waiting > 0 ? context.c.warningText : null)),
                        const TextSpan(text: ' · '),
                        TextSpan(
                            text: '${s?.errors ?? 0} errors',
                            style: TextStyle(color: (s?.errors ?? 0) > 0 ? context.c.dangerText : null)),
                        if (rejected > 0)
                          TextSpan(
                              text: ' · $rejected rejected',
                              style: TextStyle(color: context.c.dangerText)),
                        if (con.fullLoggingUntil.value != null)
                          TextSpan(
                              text: ' · FULL',
                              style: TextStyle(color: context.c.warningText, fontWeight: FontWeight.w800)),
                      ]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Upload now',
                    visualDensity: VisualDensity.compact,
                    icon: con.uploading.value
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload_outlined),
                    onPressed: con.uploading.value
                        ? null
                        : () async {
                            final msg = await con.uploadNow();
                            Get.snackbar('Upload', msg, snackPosition: SnackPosition.BOTTOM);
                          },
                  ),
                  PopupMenuButton<bool>(
                    tooltip: 'Clear logs',
                    icon: const Icon(Icons.delete_outline),
                    padding: EdgeInsets.zero,
                    onSelected: (onlySent) => _confirmClear(onlySent: onlySent),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: true, child: Text('Clear sent logs')),
                      PopupMenuItem(
                          value: false,
                          child: Text('Clear ALL logs', style: TextStyle(color: context.c.dangerText))),
                    ],
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  const SizedBox(width: 8),
                ]),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: const Text('Full logging (24 h)'),
                      subtitle: Text(
                          con.fullLoggingUntil.value == null
                              ? 'Off: only errors and warnings are saved'
                              : 'On until ${logTimeFormat.format(con.fullLoggingUntil.value!)}: every step is saved',
                          style: small),
                      value: con.fullLoggingUntil.value != null,
                      onChanged: con.setFullLogging,
                    ),
                    Text(
                        'Sent ${s?.sent ?? 0} · Waiting $waiting · Rejected $rejected · '
                        'Warnings ${s?.warnings ?? 0}',
                        style: small),
                    Text(
                        'Last upload: ${last == null ? 'not yet (this session)' : logTimeFormat.format(last)}'
                        '${LogUploader.lastResult == null ? '' : ' · ${LogUploader.lastResult}'}',
                        style: small),
                    if (paused != null && DateTime.now().isBefore(paused))
                      Text('Uploads paused until ${logTimeFormat.format(paused)}',
                          style: small?.copyWith(color: context.c.warningText)),
                    if (s?.oldest != null)
                      Text(
                          'Oldest ${logTimeFormat.format(s!.oldest!)} · newest ${logTimeFormat.format(s.newest!)}',
                          style: small),
                    Text('Device ${AppLogger.deviceId ?? '?'} · ${AppLogger.deviceSummary ?? ''}',
                        style: small),
                    Text('Server ${GlobalConfiguration().getValue('api_base_url')}',
                        style: small),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _LogTile extends StatelessWidget {
  final AppLog log;
  const _LogTile({required this.log});

  IconData get _uploadIcon => switch (log.uploadState) {
        1 => Icons.cloud_done,
        2 => Icons.block,
        _ => Icons.cloud_queue,
      };

  @override
  Widget build(BuildContext context) {
    return LogTile(
      level: log.level,
      action: log.action,
      message: log.message,
      time: log.clientTime,
      meta: [log.userId, log.docNum, log.screen],
      trailingIcon: _uploadIcon,
      onTap: () => LogDetailPage.open('Log #${log.localId}', {
        'Time (device)': logTimeFormat.format(log.clientTime),
        'Level': log.level,
        'Action': log.action,
        'Message': log.message,
        'Screen': log.screen,
        'User': log.userId,
        'Company': log.company,
        'Document': [log.docType, log.docNum].whereType<String>().join(' '),
        'Device': log.deviceId,
        'App version': log.appVersion,
        'Upload': switch (log.uploadState) {
          1 => 'Sent to server',
          2 => 'Rejected by server',
          _ => 'Waiting to upload',
        },
        'Details': log.details,
      }),
    );
  }
}
