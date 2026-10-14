import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../db/log_db.dart';
import '../../model/app_log.dart';
import '../../model/log_filter.dart';
import '../../service/app_logger.dart';
import '../../service/log_uploader.dart';

/// "This device" tab of the logs dashboard: logs stored on this scanner.
class DeviceLogsController extends GetxController {
  final LogDB db;
  DeviceLogsController(this.db);

  static const int pageSize = 100;

  final logs = <AppLog>[].obs;
  final stats = Rxn<LogStats>();
  final filter = const LogFilter().obs;
  final searchController = TextEditingController();
  final statusExpanded = false.obs;

  final loading = false.obs;
  final loadingMore = false.obs;
  final hasMore = true.obs;
  final uploading = false.obs;

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

  Future<List<AppLog>> _page({int? beforeId}) {
    final f = filter.value;
    return db.search(
      levels: f.levels,
      actions: f.actions,
      screen: f.screen,
      userId: f.userId,
      docType: f.docType,
      uploadState: f.uploadState,
      text: searchController.text,
      from: f.from,
      to: f.toExclusive,
      beforeId: beforeId,
      limit: pageSize,
    );
  }

  Future<void> refreshAll() async {
    loading.value = true;
    try {
      stats.value = await db.stats();
      final page = await _page();
      logs.assignAll(page);
      hasMore.value = page.length == pageSize;
    } finally {
      loading.value = false;
    }
  }

  /// Called when the list is scrolled to the end.
  Future<void> loadMore() async {
    if (loadingMore.value || !hasMore.value || logs.isEmpty) return;
    loadingMore.value = true;
    try {
      final page = await _page(beforeId: logs.last.localId);
      logs.addAll(page);
      hasMore.value = page.length == pageSize;
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

  /// Values for the filter sheet dropdowns (Action, Screen, UserID, DocType).
  Future<List<({String value, int count})>> valuesOf(String column) =>
      db.distinctValues(column);

  void onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), refreshAll);
  }

  void clearSearch() {
    searchController.clear();
    refreshAll();
  }

  /// "Upload now": sends waiting logs immediately, even if uploads are paused.
  Future<String> uploadNow() async {
    uploading.value = true;
    try {
      final sent = await LogUploader.uploadNow(force: true);
      await refreshAll();
      return sent > 0 ? 'Sent $sent logs' : (LogUploader.lastResult ?? 'Nothing to send');
    } finally {
      uploading.value = false;
    }
  }

  /// [onlySent] keeps logs that have not reached the server yet.
  Future<int> clear({required bool onlySent}) async {
    final removed = await db.clear(onlySent: onlySent);
    AppLogger.warn('LocalLogsCleared',
        onlySent ? 'Admin cleared $removed sent logs on this device' : 'Admin cleared ALL $removed logs on this device');
    await refreshAll();
    return removed;
  }
}
