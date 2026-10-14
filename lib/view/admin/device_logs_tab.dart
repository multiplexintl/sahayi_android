import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:global_configuration/global_configuration.dart';

import '../../controller/admin/device_logs_controller.dart';
import '../../model/app_log.dart';
import '../../service/app_logger.dart';
import '../../service/log_uploader.dart';
import 'log_widgets.dart';

/// "This device" tab: status, filters and the logs stored on this scanner.
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
        _StatusCard(con: con),
        _Filters(con: con),
        const Divider(height: 1),
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
                      padding: const EdgeInsets.all(16),
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

class _StatusCard extends StatelessWidget {
  final DeviceLogsController con;
  const _StatusCard({required this.con});

  Future<void> _confirmClear(BuildContext context, {required bool onlySent}) async {
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
              backgroundColor: Colors.red, foregroundColor: Colors.white),
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
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Obx(() {
          final s = con.stats.value;
          final paused = LogUploader.pausedUntil;
          final last = LogUploader.lastSuccessAt;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CountTile('Total', s?.total ?? 0),
                CountTile('Waiting', s?.waiting ?? 0,
                    color: (s?.waiting ?? 0) > 0 ? Colors.orange : null),
                CountTile('Sent', s?.sent ?? 0, color: Colors.green),
                CountTile('Rejected', s?.rejected ?? 0,
                    color: (s?.rejected ?? 0) > 0 ? Colors.red : null),
              ]),
              const SizedBox(height: 8),
              Text('Errors ${s?.errors ?? 0} · Warnings ${s?.warnings ?? 0}', style: small),
              Text(
                  'Last upload: ${last == null ? 'not yet (this session)' : logTimeFormat.format(last)}'
                  '${LogUploader.lastResult == null ? '' : ' · ${LogUploader.lastResult}'}',
                  style: small),
              if (paused != null && DateTime.now().isBefore(paused))
                Text('Uploads paused until ${logTimeFormat.format(paused)}',
                    style: small?.copyWith(color: Colors.orange)),
              Text('Device ${AppLogger.deviceId ?? '?'} · ${AppLogger.deviceSummary ?? ''}',
                  style: small),
              Text('Server ${GlobalConfiguration().getValue('api_base_url')}', style: small),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: con.uploading.value
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload),
                    label: const Text('Upload now'),
                    onPressed: con.uploading.value
                        ? null
                        : () async {
                            final msg = await con.uploadNow();
                            Get.snackbar('Upload', msg, snackPosition: SnackPosition.BOTTOM);
                          },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<bool>(
                  tooltip: 'Clear logs',
                  onSelected: (onlySent) => _confirmClear(context, onlySent: onlySent),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: true, child: Text('Clear sent logs')),
                    PopupMenuItem(
                        value: false,
                        child: Text('Clear ALL logs', style: TextStyle(color: Colors.red))),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(children: [Icon(Icons.delete_outline), Text('Clear')]),
                  ),
                ),
              ]),
            ],
          );
        }),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final DeviceLogsController con;
  const _Filters({required this.con});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Obx(() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LevelFilter(selected: con.level.value, onChanged: con.setLevel),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: con.searchController,
                    onChanged: con.onSearchChanged,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search action, message, doc, user',
                      suffixIcon: IconButton(
                          icon: const Icon(Icons.clear), onPressed: con.clearSearch),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              DateRangeButton(
                  from: con.from.value, to: con.to.value, onChanged: con.setDates),
            ],
          )),
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
    final small = Theme.of(context).textTheme.labelSmall;
    return ListTile(
      dense: true,
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
      title: Row(children: [
        LevelBadge(log.level),
        const SizedBox(width: 6),
        Expanded(
            child: Text(log.action,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
        Text(logShortTimeFormat.format(log.clientTime), style: small),
        const SizedBox(width: 4),
        Icon(_uploadIcon, size: 14, color: Colors.grey),
      ]),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(log.message, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (log.docNum != null || log.userId != null || log.screen != null)
            Text(
                [log.userId, log.docNum, log.screen].whereType<String>().join(' · '),
                style: small,
                overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
