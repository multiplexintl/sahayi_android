import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../model/log_filter.dart';
import '../../model/server_log.dart';
import '../../repo/admin_logs_repo.dart';
import '../../service/app_logger.dart';

/// "All devices" tab of the logs dashboard: logs on the server, every scanner.
class ServerLogsController extends GetxController {
  final AdminLogsRepo repo;
  ServerLogsController(this.repo);

  static const int pageSize = 100;

  final logs = <ServerLog>[].obs;
  final summary = Rxn<ServerLogSummary>();
  final filter = const LogFilter().obs;
  final device = RxnString(); // selected DeviceID, null = all devices
  final searchController = TextEditingController();
  final statusExpanded = false.obs;

  final loading = false.obs;
  final loadingMore = false.obs;
  final hasMore = true.obs;
  final error = RxnString(); // shown instead of the list when loading fails

  Timer? _searchDebounce;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    searchController.dispose();
    super.onClose();
  }

  Future<List<ServerLog>> _page({int? beforeLogId}) => repo.search(
        filter.value,
        text: searchController.text,
        deviceId: device.value,
        beforeLogId: beforeLogId,
        top: pageSize,
      );

  /// Loads the summary and the list independently, so one failing does not
  /// hide the other. A list failure is shown instead of the list.
  Future<void> refreshAll() async {
    loading.value = true;
    error.value = null;
    final f = filter.value;
    try {
      await Future.wait([
        () async {
          try {
            summary.value = await repo.summary(from: f.from, toExclusive: f.toExclusive);
          } catch (e) {
            AppLogger.warn('AdminLogsError', 'All devices summary could not load: $e');
          }
        }(),
        () async {
          try {
            final page = await _page();
            logs.assignAll(page);
            hasMore.value = page.length == pageSize;
          } catch (e, st) {
            error.value = e.toString();
            logs.clear();
            AppLogger.warn('AdminLogsError', 'All devices list could not load: $e',
                details: 'Device filter: ${device.value ?? 'all'} | Stack: $st');
          }
        }(),
      ]);
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (loadingMore.value || !hasMore.value || logs.isEmpty || error.value != null) return;
    loadingMore.value = true;
    try {
      final page = await _page(beforeLogId: logs.last.logId);
      logs.addAll(page);
      hasMore.value = page.length == pageSize;
    } catch (e) {
      hasMore.value = false;
      AppLogger.warn('AdminLogsError', 'All devices tab could not load more: $e');
      Get.snackbar('Could not load more', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      loadingMore.value = false;
    }
  }

  void setFilter(LogFilter f) {
    filter.value = f;
    refreshAll();
  }

  void setPreset(LogPreset p) => setFilter(p.apply(filter.value));

  void setDates(DateTime? start, DateTime? end) =>
      setFilter(filter.value.copyWith(from: () => start, to: () => end));

  void setDevice(String? deviceId) {
    device.value = deviceId;
    refreshAll();
  }

  Future<List<({String value, int count})>> valuesOf(String column) => repo.values(column);

  void onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), refreshAll);
  }

  void clearSearch() {
    searchController.clear();
    refreshAll();
  }

  /// Clear logs on the server. Returns rows deleted.
  Future<int> deleteOnServer({String? deviceId, DateTime? beforeDate, bool all = false}) async {
    final deleted = await repo.delete(deviceId: deviceId, beforeDate: beforeDate, all: all);
    AppLogger.warn(
        'ServerLogsCleared',
        all
            ? 'Admin cleared ALL server logs ($deleted rows)'
            : 'Admin cleared $deleted server logs'
                '${deviceId != null ? ' for $deviceId' : ''}'
                '${beforeDate != null ? ' older than $beforeDate' : ''}');
    if (deviceId != null && device.value == deviceId) device.value = null;
    await refreshAll();
    return deleted;
  }
}
