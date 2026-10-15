import 'package:flutter/material.dart';
import 'package:sahayi_android/ui/ui.dart';
import 'package:get/get.dart';

import '../../controller/admin/server_logs_controller.dart';
import '../../model/server_log.dart';
import '../../repo/admin_logs_repo.dart';
import 'log_widgets.dart';

/// "All devices" tab: logs on the server from every scanner (online admin only).
/// Same compact layout as "This device", plus a device picker and clearing
/// logs on the server.
class AllDevicesTab extends StatefulWidget {
  final AdminLogsRepo? repo; // injectable for tests

  /// Default repository (tests can replace it).
  static AdminLogsRepo Function() defaultRepo = AdminLogsRepo.new;

  const AllDevicesTab({super.key, this.repo});

  @override
  State<AllDevicesTab> createState() => _AllDevicesTabState();
}

class _AllDevicesTabState extends State<AllDevicesTab> with AutomaticKeepAliveClientMixin {
  static const _tag = 'serverLogs';
  late final ServerLogsController con;
  final _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    con = Get.put(ServerLogsController(widget.repo ?? AllDevicesTab.defaultRepo()), tag: _tag);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) con.loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    Get.delete<ServerLogsController>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _SummaryBar(con: con),
        Obx(() => FilterBar(
              search: con.searchController,
              onSearchChanged: con.onSearchChanged,
              onClearSearch: con.clearSearch,
              filter: con.filter.value,
              onDates: con.setDates,
              onMoreFilters: () async {
                final f = await FilterSheet.show(context,
                    initial: con.filter.value, valuesOf: con.valuesOf, showUploadState: false);
                if (f != null) con.setFilter(f);
              },
            )),
        Obx(() => ActiveDatesLine(filter: con.filter.value, onClear: () => con.setDates(null, null))),
        Obx(() => PresetChips(
            filter: con.filter.value, onSelected: con.setPreset, showWaiting: false)),
        const Divider(height: 8),
        Expanded(
          child: Obx(() {
            if (con.loading.value && con.logs.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (con.error.value != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cloud_off, size: 40, color: context.c.faint),
                    const SizedBox(height: 8),
                    Text(con.error.value!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: con.refreshAll, child: const Text('Try again')),
                  ]),
                ),
              );
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
                  return _ServerLogTile(log: con.logs[i]);
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// One line: counts + device picker + clear + expand.
class _SummaryBar extends StatelessWidget {
  final ServerLogsController con;
  const _SummaryBar({required this.con});

  Future<void> _pickDevice(BuildContext context) async {
    final devices = con.summary.value?.deviceList ?? const <ServerDevice>[];
    final picked = await showModalBottomSheet<({String? id})>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _DevicePicker(devices: devices, selected: con.device.value),
    );
    if (picked != null) con.setDevice(picked.id);
  }

  Future<void> _clear(BuildContext context, String mode) async {
    final devices = con.summary.value?.deviceList ?? const <ServerDevice>[];
    switch (mode) {
      case 'device':
        String? id = con.device.value;
        if (id == null) {
          final picked = await showModalBottomSheet<({String? id})>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            builder: (_) =>
                _DevicePicker(devices: devices, selected: null, title: 'Clear logs of which device?'),
          );
          id = picked?.id;
        }
        if (id == null) return;
        final count = devices.firstWhereOrNull((d) => d.deviceId == id)?.total;
        if (await _confirm('Clear logs of $id?',
            '${count ?? 'All'} logs of this device are deleted from the server. This cannot be undone.')) {
          await _run(() => con.deleteOnServer(deviceId: id));
        }
      case 'date':
        final now = DateTime.now();
        final day = await showDatePicker(
          context: context,
          helpText: 'Delete logs OLDER than (server time)',
          firstDate: now.subtract(const Duration(days: 365)),
          lastDate: now,
          initialDate: now.subtract(const Duration(days: 30)),
        );
        if (day == null) return;
        final label = logTimeFormat.format(day).split(' ').first;
        if (await _confirm('Clear logs older than $label?',
            'Logs of ALL devices saved before $label are deleted from the server. This cannot be undone.')) {
          await _run(() => con.deleteOnServer(beforeDate: day));
        }
      case 'all':
        if (await _typedConfirm()) {
          await _run(() => con.deleteOnServer(all: true));
        }
    }
  }

  Future<void> _run(Future<int> Function() action) async {
    try {
      final n = await action();
      Get.snackbar('Cleared', '$n logs deleted on the server', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Not cleared', e.toString(),
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Get.context!.c.dangerSoft, colorText: Get.context!.c.dangerText);
    }
  }

  Future<bool> _confirm(String title, String text) async =>
      await Get.dialog<bool>(AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Get.context!.c.dangerSoft, foregroundColor: Get.context!.c.dangerText),
            onPressed: () => Get.back(result: true),
            child: const Text('Delete'),
          ),
        ],
      )) ==
      true;

  /// "Everything" needs the words DELETE ALL typed exactly.
  Future<bool> _typedConfirm() async {
    final typed = TextEditingController();
    final ok = await Get.dialog<bool>(StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: const Text('Delete ALL logs on the server?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Every log from every device is deleted. This cannot be undone.\n\n'
              'Type DELETE ALL to confirm.'),
          TextField(
            controller: typed,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.c.dangerSoft, foregroundColor: context.c.dangerText),
            onPressed: typed.text.trim() == 'DELETE ALL' ? () => Get.back(result: true) : null,
            child: const Text('Delete everything'),
          ),
        ],
      ),
    ));
    typed.dispose();
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Obx(() {
        final s = con.summary.value;
        final expanded = con.statusExpanded.value;
        final device = con.device.value;
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
                        TextSpan(text: '${s?.total ?? 0} logs · ${s?.devices ?? 0} devices · '),
                        TextSpan(
                            text: '${s?.errors ?? 0} errors',
                            style: TextStyle(color: (s?.errors ?? 0) > 0 ? context.c.dangerText : null)),
                      ]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.refresh),
                    onPressed: con.loading.value ? null : con.refreshAll,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Clear on server',
                    icon: const Icon(Icons.delete_outline),
                    padding: EdgeInsets.zero,
                    onSelected: (m) => _clear(context, m),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'device',
                          child: Text(device == null ? 'Clear one device…' : 'Clear $device')),
                      const PopupMenuItem(value: 'date', child: Text('Clear older than a date…')),
                      PopupMenuItem(
                          value: 'all',
                          child: Text('Clear EVERYTHING…', style: TextStyle(color: context.c.dangerText))),
                    ],
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  const SizedBox(width: 8),
                ]),
              ),
            ),
            // Device picker: always visible, one line
            InkWell(
              onTap: () => _pickDevice(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Row(children: [
                  Icon(Icons.phone_android,
                      size: 16, color: device == null ? null : Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(device ?? 'All devices',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (device != null)
                    InkWell(
                      onTap: () => con.setDevice(null),
                      child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.close, size: 16)),
                    ),
                  const Icon(Icons.arrow_drop_down),
                ]),
              ),
            ),
            if (expanded && s != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Errors ${s.errors} · Warnings ${s.warnings} · Info ${s.infos}', style: small),
                    if (s.firstLog != null)
                      Text(
                          'Oldest ${logTimeFormat.format(s.firstLog!)} · newest ${logTimeFormat.format(s.lastLog!)} (server time)',
                          style: small),
                    Text('Counts follow the date filter; the device picker shows each device.',
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

/// Bottom sheet listing devices (last seen, user, version, errors).
class _DevicePicker extends StatelessWidget {
  final List<ServerDevice> devices;
  final String? selected;
  final String title;
  const _DevicePicker({required this.devices, this.selected, this.title = 'Show logs of'});

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall;
    final scanners = devices.where((d) => d.deviceId != null).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        children: [
          ListTile(title: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (title == 'Show logs of')
            ListTile(
              dense: true,
              leading: const Icon(Icons.devices),
              title: const Text('All devices'),
              selected: selected == null,
              onTap: () => Navigator.of(context).pop((id: null)),
            ),
          if (scanners.isEmpty)
            const ListTile(dense: true, title: Text('No devices have sent logs in this period.')),
          for (final d in scanners)
            ListTile(
              dense: true,
              selected: selected == d.deviceId,
              leading: Icon(Icons.phone_android, color: d.errors > 0 ? context.c.dangerText : null),
              title: Text(d.deviceId!, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  'Last seen ${logTimeFormat.format(d.lastSeen)}\n'
                  '${d.lastUserId ?? '-'} · v${d.lastAppVersion ?? '?'} · '
                  '${d.total} logs · ${d.errors} errors · ${d.warnings} warnings',
                  style: small),
              isThreeLine: true,
              onTap: () => Navigator.of(context).pop((id: d.deviceId)),
            ),
        ],
      ),
    );
  }
}

class _ServerLogTile extends StatelessWidget {
  final ServerLog log;
  const _ServerLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    return LogTile(
      level: log.level,
      action: log.action,
      message: log.message,
      time: log.time,
      meta: [log.source == 'API' ? 'API' : log.deviceId, log.userId, log.docNum, log.screen],
      onTap: () => LogDetailPage.open('Server log #${log.logId}', {
        'Time (device)': log.clientTime == null ? null : logTimeFormat.format(log.clientTime!),
        'Time (server)': logTimeFormat.format(log.loggedAt),
        'Source': log.source,
        'Level': log.level,
        'Action': log.action,
        'Message': log.message,
        'Device': log.deviceId,
        'Screen': log.screen,
        'User': log.userId,
        'Company': log.company,
        'Document': [log.docType, log.docNum].whereType<String>().join(' '),
        'App version': log.appVersion,
        'Details': log.details,
      }),
    );
  }
}
