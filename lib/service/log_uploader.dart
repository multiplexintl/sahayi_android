import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../db/log_db.dart';
import '../helper/http_client_helper.dart';

/// Sends device logs to POST {api}/v2/Logs automatically.
///
/// - A few seconds after a log is saved, pending logs are sent in batches.
/// - Every minute it tries again, so logs written while offline go up once
///   the connection is back.
/// - If the server does not have the endpoint (404/405), it pauses for
///   30 minutes instead of trying constantly.
/// - It never writes logs about itself (that would loop forever); problems are
///   printed to the debug console only.
class LogUploader {
  LogUploader._();

  static const int batchSize = 200;
  static const int maxBatchesPerRun = 20;
  static Duration debounce = const Duration(seconds: 3);
  static const Duration every = Duration(minutes: 1);
  static const Duration notDeployedPause = Duration(minutes: 30);

  static Uri? _endpoint;
  static LogDB? _db;
  static Future<http.Client> Function() _client =
      () => HttpClientHelper().getClient();

  static Timer? _debounceTimer;
  static Timer? _periodic;
  static bool _busy = false;
  static bool _runAgain = false;
  static DateTime? _pausedUntil;

  /// For the dashboard: when the server last accepted logs, and the last outcome.
  static DateTime? lastSuccessAt;
  static String? lastResult;
  static DateTime? get pausedUntil => _pausedUntil;

  /// [apiBaseUrl] like "https://testsahayiapi.multiroute.ae/api/".
  static void start({
    required String apiBaseUrl,
    required LogDB db,
    Future<http.Client> Function()? client,
  }) {
    _endpoint = Uri.parse('${apiBaseUrl}v2/Logs');
    _db = db;
    if (client != null) _client = client;
    _periodic?.cancel();
    _periodic = Timer.periodic(every, (_) => uploadNow());
    notify();
  }

  /// Something new was logged: upload soon (several logs share one request).
  static void notify() {
    if (_endpoint == null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, uploadNow);
  }

  /// Sends everything pending now. Returns how many entries the server accepted.
  /// [force] ignores a pause (used by the dashboard's "Upload now" button).
  static Future<int> uploadNow({bool force = false}) async {
    final endpoint = _endpoint;
    final db = _db;
    if (endpoint == null || db == null) return 0;
    if (force) _pausedUntil = null;
    if (_pausedUntil != null && DateTime.now().isBefore(_pausedUntil!)) return 0;
    if (_busy) {
      _runAgain = true;
      return 0;
    }

    _busy = true;
    var accepted = 0;
    try {
      for (var i = 0; i < maxBatchesPerRun; i++) {
        final batch = await db.notUploaded(limit: batchSize);
        if (batch.isEmpty) break;
        final ids = batch.map((e) => e.localId!).toList();

        final client = await _client();
        final response = await client.post(
          endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(batch.map((e) => e.toApiJson()).toList()),
        );

        if (response.statusCode == 200) {
          await db.markUploaded(ids);
          accepted += ids.length;
          lastSuccessAt = DateTime.now();
          lastResult = 'Sent $accepted';
          continue;
        }
        if (response.statusCode == 404 || response.statusCode == 405) {
          _pausedUntil = DateTime.now().add(notDeployedPause);
          lastResult = 'Server has no log endpoint (HTTP ${response.statusCode}); paused 30 min';
          dev.log('Log upload: endpoint not on this server, pausing 30 min',
              name: 'LogUploader');
          break;
        }
        if (response.statusCode == 400) {
          // The server will never accept these; skip them so the queue moves on.
          await db.markRejected(ids);
          lastResult = '${ids.length} rejected by server';
          dev.log('Log upload: ${ids.length} entries rejected: ${response.body}',
              name: 'LogUploader');
          continue;
        }
        dev.log('Log upload: HTTP ${response.statusCode}, will retry',
            name: 'LogUploader');
        lastResult = 'Server error HTTP ${response.statusCode}; will retry';
        break; // server error: next periodic run tries again
      }
    } catch (e) {
      // Offline, timeout, etc. Logs stay on the device for the next attempt.
      dev.log('Log upload failed, will retry: $e', name: 'LogUploader');
      lastResult = 'Not sent (no connection?); will retry';
    } finally {
      _busy = false;
    }

    if (_runAgain) {
      _runAgain = false;
      notify();
    }
    return accepted;
  }

  @visibleForTesting
  static void resetForTest() {
    _debounceTimer?.cancel();
    _periodic?.cancel();
    _debounceTimer = _periodic = null;
    _endpoint = null;
    _db = null;
    _client = () => HttpClientHelper().getClient();
    _busy = _runAgain = false;
    _pausedUntil = null;
    lastSuccessAt = null;
    lastResult = null;
    debounce = const Duration(seconds: 3);
  }
}
