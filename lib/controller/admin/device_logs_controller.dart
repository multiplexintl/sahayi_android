import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../db/log_db.dart';
import '../../model/app_log.dart';
import '../../service/app_logger.dart';
import '../../service/log_uploader.dart';

/// "This device" tab of the logs dashboard: logs stored on this scanner.
class DeviceLogsController extends GetxController {
  final LogDB db;
  DeviceLogsController(this.db);

  static const int pageSize = 100;

  final logs = <AppLog>[].obs;
  final stats = Rxn<LogStats>();
  final level = RxnString();
  final from = Rxn<DateTime>();
  final to = Rxn<DateTime>(); // inclusive day
  final searchController = TextEditingController();

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

  Future<List<AppLog>> _page({int? beforeId}) => db.search(
        level: level.value,
        text: searchController.text,
        from: from.value,
        // the picked "to" day is inclusive: search up to the next midnight
        to: to.value == null
            ? null
            : DateTime(to.value!.year, to.value!.month, to.value!.day + 1),
        beforeId: beforeId,
        limit: pageSize,
      );

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

  void setLevel(String? value) {
    level.value = value;
    refreshAll();
  }

  void setDates(DateTime? start, DateTime? end) {
    from.value = start;
    to.value = end;
    refreshAll();
  }

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
        'Admin cleared $removed ${onlySent ? 'sent' : ''} logs on this device'.replaceAll('  ', ' '));
    await refreshAll();
    return removed;
  }
}
