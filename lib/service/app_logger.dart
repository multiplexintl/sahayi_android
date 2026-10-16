import 'dart:collection';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/log_db.dart';
import '../model/app_log.dart';

/// App-wide logger. Only problems are saved on the device (see [LogDB]) and
/// uploaded; everything is printed to the debug console.
///
/// What is saved:
/// - ERROR: always, with the last [breadcrumbCount] steps attached
///   ("Recent steps"), so the lead-up is visible without storing INFO rows.
/// - WARN: yes, except user mistakes / popups / network chatter
///   ([notStoredWarnings]).
/// - INFO: never, unless "full logging" is switched on in the dashboard
///   (per device, turns itself off after [fullLoggingFor]).
/// - The same problem again within [repeatWindow] is counted, not saved again.
///
/// Usage:
///   AppLogger.info('Login', 'User logged in');
///   AppLogger.error('Finalize', 'Upload failed', error: e, stack: st);
///
/// Logging never throws and never blocks the caller.
class AppLogger {
  AppLogger._();

  static LogDB? _db;
  static final List<AppLog> _pending = []; // entries logged before init finished
  static const int _maxPending = 500;
  static Future<void> _queue = Future.value(); // keeps writes in order

  // Context attached to every entry.
  static String? _deviceId;
  static String? _appVersion;
  static String? _userId;
  static String? _company;
  static String? _screen;
  static String? _deviceSummary;

  static const String _installIdKey = 'logInstallId';

  /// WARN actions that are not worth a row (the real failure, if any, is
  /// logged separately): popups, input mistakes, wrong password, network
  /// chatter (going offline is saved as one "Offline" row when it ends).
  static const Set<String> notStoredWarnings = {
    'Popup',
    'Validation',
    'LoginFailed',
    'Network',
    'NetworkCheck',
  };

  /// Recent steps kept in memory only, attached to the next ERROR.
  static const int breadcrumbCount = 20;
  static final ListQueue<String> _breadcrumbs = ListQueue();

  /// Size caps for one saved row.
  static const int maxMessage = 1000;
  static const int maxDetails = 8000;
  static const int maxStackLines = 40;

  /// Same problem again within this window: counted, not saved again.
  static Duration repeatWindow = const Duration(minutes: 5);

  /// Current time (replaceable in tests).
  static DateTime Function() clock = DateTime.now;
  static final Map<String, _Repeat> _repeats = {};

  /// "Full logging" switch (dashboard): saves INFO too, for a limited time.
  static const Duration fullLoggingFor = Duration(hours: 24);
  static const String _fullLoggingKey = 'fullLoggingUntil';
  static const String _infoCleanupKey = 'leanLoggingCleanupDone';
  static DateTime? _fullLoggingUntil;

  /// When full logging ends, or null when it is off.
  static DateTime? get fullLoggingUntil =>
      fullLogging ? _fullLoggingUntil : null;
  static bool get fullLogging =>
      _fullLoggingUntil != null && clock().isBefore(_fullLoggingUntil!);

  /// Called after each entry is saved (used by LogUploader).
  static void Function()? onSaved;

  /// The device log database, once [init] has finished.
  static LogDB? get db => _db;

  /// Call once in main() before runApp. [db] can be injected in tests.
  static Future<void> init({LogDB? db}) async {
    try {
      _db = db ?? await LogDB.open();
      await _loadContext();
      await _loadSettings();
      final removed = await _db!.purge();

      for (final entry in List.of(_pending)) {
        await _db!.insert(entry);
      }
      _pending.clear();

      if (removed > 0) info('LogPurge', 'Removed $removed old log rows');
    } catch (e) {
      dev.log('AppLogger init failed: $e', name: 'AppLog');
    }
  }

  static Future<void> _loadSettings() async {
    final db = _db!;
    final until = await db.getSetting(_fullLoggingKey);
    _fullLoggingUntil = until == null ? null : DateTime.tryParse(until);

    // One time, after updating from the version that saved everything:
    // drop INFO rows that never reached the server.
    if (await db.getSetting(_infoCleanupKey) == null) {
      final removed = await db.deleteUnsentInfo();
      await db.setSetting(_infoCleanupKey, DateTime.now().toIso8601String());
      if (removed > 0) info('LogCleanup', 'Removed $removed unsent INFO rows');
    }
  }

  /// Dashboard switch. On: also save INFO for [fullLoggingFor]. Off: stop now.
  static Future<void> setFullLogging(bool on) async {
    _fullLoggingUntil = on ? clock().add(fullLoggingFor) : null;
    await _db?.setSetting(_fullLoggingKey, _fullLoggingUntil?.toIso8601String());
    warn('FullLogging',
        on ? 'Full logging ON until $_fullLoggingUntil' : 'Full logging OFF');
  }

  static Future<void> _loadContext() async {
    try {
      final package = await PackageInfo.fromPlatform();
      _appVersion = '${package.version}+${package.buildNumber}';
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      var installId = prefs.getString(_installIdKey);
      if (installId == null) {
        final rnd = Random.secure();
        installId = List.generate(8, (_) => rnd.nextInt(16).toRadixString(16))
            .join();
        await prefs.setString(_installIdKey, installId);
      }
      String model = 'unknown';
      try {
        final android = await DeviceInfoPlugin().androidInfo;
        model = android.model;
        _deviceSummary = '${android.manufacturer} ${android.model}, '
            'Android ${android.version.release} (SDK ${android.version.sdkInt})';
      } catch (_) {}
      // e.g. "EDA52-3f9a1c2b": device model + random ID of this installation
      _deviceId = '$model-$installId';
    } catch (_) {}
  }

  /// e.g. "EDA52-3f9a1c2b"
  static String? get deviceId => _deviceId;

  /// e.g. "Honeywell EDA52, Android 11 (SDK 30)"
  static String? get deviceSummary => _deviceSummary;

  /// Employee currently attached to every log (null before login).
  static String? get userId => _userId;

  // ---- context setters ----
  static void setUser(String? userId) => _userId = userId;
  static void setCompany(String? company) => _company = company;
  static void setScreen(String? screen) => _screen = screen;

  // ---- logging ----
  static void info(String action, String message,
          {String? docNum, String? docType, String? details}) =>
      _write('INFO', action, message, docNum, docType, details);

  static void warn(String action, String message,
          {String? docNum, String? docType, String? details}) =>
      _write('WARN', action, message, docNum, docType, details);

  static void error(String action, String message,
      {Object? error,
      StackTrace? stack,
      String? docNum,
      String? docType,
      String? details}) {
    final parts = [
      if (details != null) details,
      if (error != null) 'Error: ${_cut('$error', 2000)}',
      if (stack != null) 'Stack: ${shortStack(stack)}',
    ];
    _write('ERROR', action, message, docNum, docType,
        parts.isEmpty ? null : parts.join('\n'));
  }

  static void _write(String level, String action, String message,
      String? docNum, String? docType, String? details) {
    try {
      dev.log('$level $action: $message${details != null ? ' | $details' : ''}',
          name: 'AppLog');
      if (_repeats.isNotEmpty) reportRepeats();

      final store = level == 'ERROR' ||
          (level == 'WARN' && !notStoredWarnings.contains(action)) ||
          fullLogging;
      if (!store) {
        _remember(level, action, message);
        return;
      }

      // Same problem again shortly after: count it instead of a new row.
      if (level != 'INFO' && _isRepeat(level, action, message)) {
        _remember(level, action, '(repeat) $message');
        return;
      }

      var fullDetails = details == null ? null : _cut(details, maxDetails);
      if (level == 'ERROR' && _breadcrumbs.isNotEmpty) {
        fullDetails = [
          if (fullDetails != null) fullDetails,
          'Recent steps (oldest first):\n${_breadcrumbs.join('\n')}',
        ].join('\n\n');
      }
      _remember(level, action, message);
      _save(AppLog(
        clientTime: clock(),
        level: level,
        userId: _userId,
        company: _company,
        deviceId: _deviceId,
        appVersion: _appVersion,
        screen: _screen,
        action: action,
        docNum: docNum,
        docType: docType,
        message: _cut(message, maxMessage),
        details: fullDetails,
      ));
    } catch (e) {
      dev.log('AppLogger failed: $e', name: 'AppLog');
    }
  }

  static void _save(AppLog entry) {
    final db = _db;
    if (db == null) {
      if (_pending.length < _maxPending) _pending.add(entry);
      return;
    }
    _queue = _queue.then((_) => db.insert(entry)).then((_) => onSaved?.call(),
        onError: (Object e) =>
            dev.log('AppLogger write failed: $e', name: 'AppLog'));
  }

  /// Adds one line to the in-memory "recent steps".
  static void _remember(String level, String action, String message) {
    final t = clock();
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
    final oneLine = message.replaceAll('\n', ' ');
    _breadcrumbs.addLast(
        '$time ${level == 'INFO' ? '' : '$level '}$action: ${_cut(oneLine, 160)}');
    while (_breadcrumbs.length > breadcrumbCount) {
      _breadcrumbs.removeFirst();
    }
  }

  /// Numbers and widget ids (#1a2b3, any length) differ between repeats of one problem.
  static String repeatKey(String level, String action, String message) =>
      '$level|$action|${message.replaceAll(RegExp(r'#[0-9a-f]+'), '#').replaceAll(RegExp(r'\d+'), 'N')}';

  static bool _isRepeat(String level, String action, String message) {
    final key = repeatKey(level, action, message);
    final r = _repeats[key];
    if (r != null && clock().difference(r.first) < repeatWindow) {
      r.count++;
      return true;
    }
    _repeats[key] = _Repeat(level, action, message, clock());
    return false;
  }

  /// Saves one "Repeated" row for each problem whose window has ended and
  /// that happened again inside it. Runs on every log and before each upload
  /// (no timers).
  static void reportRepeats() {
    try {
      final now = clock();
      final ended = _repeats.entries
          .where((e) => now.difference(e.value.first) >= repeatWindow)
          .toList();
      for (final e in ended) {
        _repeats.remove(e.key);
        final r = e.value;
        if (r.count == 0) continue;
        _save(AppLog(
          clientTime: now,
          level: 'WARN',
          userId: _userId,
          company: _company,
          deviceId: _deviceId,
          appVersion: _appVersion,
          screen: _screen,
          action: 'Repeated',
          message: _cut(
              '${r.level} "${r.action}" happened ${r.count} more time(s) within '
              '${repeatWindow.inMinutes} min of ${r.first}: ${r.message}',
              maxMessage),
        ));
      }
    } catch (e) {
      dev.log('AppLogger reportRepeats failed: $e', name: 'AppLog');
    }
  }

  /// First [maxStackLines] lines of a stack trace.
  static String shortStack(StackTrace stack) {
    final lines = stack.toString().trimRight().split('\n');
    if (lines.length <= maxStackLines) return lines.join('\n');
    return '${lines.take(maxStackLines).join('\n')}\n... (${lines.length - maxStackLines} more lines)';
  }

  static String _cut(String text, int max) => text.length <= max
      ? text
      : '${text.substring(0, max)}... (${text.length - max} more chars)';

  /// Completes when every entry logged so far has been saved.
  static Future<void> flush() => _queue;

  @visibleForTesting
  static void resetForTest() {
    _db = null;
    _pending.clear();
    _queue = Future.value();
    _userId = _company = _screen = null;
    onSaved = null;
    _breadcrumbs.clear();
    _repeats.clear();
    clock = DateTime.now;
    _fullLoggingUntil = null;
    repeatWindow = const Duration(minutes: 5);
  }

  /// Latest entries, newest first (for debugging / a future log viewer).
  static Future<List<AppLog>> recent({int limit = 100}) async =>
      await _db?.recent(limit: limit) ?? [];
}

class _Repeat {
  final String level, action, message;
  final DateTime first;
  int count = 0;
  _Repeat(this.level, this.action, this.message, this.first);
}
