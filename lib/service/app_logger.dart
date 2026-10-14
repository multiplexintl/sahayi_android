import 'dart:developer' as dev;
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/log_db.dart';
import '../model/app_log.dart';

/// App-wide logger. Saves every entry on the device (see [LogDB]) and also
/// prints it to the debug console.
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

  /// Called after each entry is saved (used by LogUploader).
  static void Function()? onSaved;

  /// The device log database, once [init] has finished.
  static LogDB? get db => _db;

  /// Call once in main() before runApp. [db] can be injected in tests.
  static Future<void> init({LogDB? db}) async {
    try {
      _db = db ?? await LogDB.open();
      await _loadContext();
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
      if (error != null) 'Error: $error',
      if (stack != null) 'Stack: $stack',
    ];
    _write('ERROR', action, message, docNum, docType,
        parts.isEmpty ? null : parts.join('\n'));
  }

  static void _write(String level, String action, String message,
      String? docNum, String? docType, String? details) {
    try {
      final entry = AppLog(
        clientTime: DateTime.now(),
        level: level,
        userId: _userId,
        company: _company,
        deviceId: _deviceId,
        appVersion: _appVersion,
        screen: _screen,
        action: action,
        docNum: docNum,
        docType: docType,
        message: message,
        details: details,
      );

      dev.log('$level $action: $message${details != null ? ' | $details' : ''}',
          name: 'AppLog');

      final db = _db;
      if (db == null) {
        if (_pending.length < _maxPending) _pending.add(entry);
        return;
      }
      _queue = _queue.then((_) => db.insert(entry)).then((_) => onSaved?.call(),
          onError: (Object e) =>
              dev.log('AppLogger write failed: $e', name: 'AppLog'));
    } catch (e) {
      dev.log('AppLogger failed: $e', name: 'AppLog');
    }
  }

  /// Completes when every entry logged so far has been saved.
  static Future<void> flush() => _queue;

  @visibleForTesting
  static void resetForTest() {
    _db = null;
    _pending.clear();
    _queue = Future.value();
    _userId = _company = _screen = null;
    onSaved = null;
  }

  /// Latest entries, newest first (for debugging / a future log viewer).
  static Future<List<AppLog>> recent({int limit = 100}) async =>
      await _db?.recent(limit: limit) ?? [];
}
