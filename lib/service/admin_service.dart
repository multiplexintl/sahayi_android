import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:global_configuration/global_configuration.dart';

import '../db/log_db.dart';
import '../helper/http_client_helper.dart';
import 'app_logger.dart';

/// How the admin got in.
enum AdminMode {
  /// Server-checked login (Users.Role = ADMIN): this device + all devices.
  online,

  /// Offline PIN: this device's own logs only.
  offlinePin,
}

/// The admin who unlocked the logs dashboard. Kept in memory only and cleared
/// when the dashboard is closed.
class AdminSession {
  final AdminMode mode;
  final String? userId;
  final String? userName;
  final String? _password;

  const AdminSession._(this.mode, this.userId, this.userName, this._password);

  bool get canSeeAllDevices => mode == AdminMode.online;

  /// Headers for the admin-only server endpoints (sent over HTTPS).
  Map<String, String> get headers => {
        'X-Admin-User': userId ?? '',
        'X-Admin-Password': _password ?? '',
      };
}

/// Hidden logs-dashboard access: online admin login, or an offline PIN.
class AdminService {
  AdminService._();

  static AdminSession? current;

  // Scrambled offline PIN (salt + 100,000 x SHA-256). The PIN itself is not
  // stored anywhere; this pair is copied into the device's log database.
  static const String _defaultPinSalt = 'd3dda7980fa5833c3fcaa3c266ba79e0';
  static const String _defaultPinHash =
      '437a22bf91b1dc8764379098c3cbfe0bb1d80291346c99db22817025dfd7f760';
  static const String pinSaltKey = 'AdminPinSalt';
  static const String pinHashKey = 'AdminPinHash';
  static const int pinRounds = 100000;

  static const int _maxPinFailures = 5;
  static const Duration _pinLockFor = Duration(minutes: 5);
  static int _pinFailures = 0;
  static DateTime? _pinLockedUntil;

  /// Online admin login. Returns null on success, otherwise a message to show.
  static Future<String?> login(String userId, String password) async {
    userId = userId.trim();
    if (userId.isEmpty || password.isEmpty) return 'Enter user ID and password.';

    try {
      final client = await HttpClientHelper().getClient();
      final url = Uri.parse(
          '${GlobalConfiguration().getValue('api_base_url')}v2/Admin/Login');
      final response = await client.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'UserID': userId, 'Password': password}));

      if (response.statusCode == 200) {
        final user = jsonDecode(response.body) as Map<String, dynamic>;
        current = AdminSession._(AdminMode.online, user['UserID'] as String?,
            user['UserName'] as String?, password);
        AppLogger.info('AdminLogin', 'Admin $userId opened the logs dashboard');
        return null;
      }
      if (response.statusCode == 429) {
        AppLogger.warn('AdminLoginFailed', 'Admin login locked for $userId');
        return 'Too many wrong attempts. Try again in 15 minutes.';
      }
      if (response.statusCode == 401) {
        AppLogger.warn('AdminLoginFailed', 'Wrong admin login for $userId');
        return 'Wrong user ID or password, or not an admin.';
      }
      if (response.statusCode == 404) {
        return 'This server does not support the logs dashboard yet. Use the offline PIN.';
      }
      return 'Server error (HTTP ${response.statusCode}). Try again or use the offline PIN.';
    } on SocketException {
      return 'No connection. Use the offline PIN to see this device\'s logs.';
    } catch (e) {
      return 'Could not reach the server ($e). Use the offline PIN.';
    }
  }

  /// Offline PIN check. Returns null on success, otherwise a message to show.
  static Future<String?> unlockWithPin(String pin, {LogDB? db}) async {
    final now = DateTime.now();
    if (_pinLockedUntil != null && now.isBefore(_pinLockedUntil!)) {
      return 'Too many wrong PINs. Try again in a few minutes.';
    }
    if (pin.trim().isEmpty) return 'Enter the PIN.';

    final store = db ?? AppLogger.db;
    if (store == null) return 'Logs are not available on this device.';

    await _ensurePinStored(store);
    final salt = await store.getSetting(pinSaltKey);
    final expected = await store.getSetting(pinHashKey);
    final actual = await compute(_hashPinIsolate, [salt ?? '', pin.trim()]);

    if (actual == expected) {
      _pinFailures = 0;
      current = const AdminSession._(AdminMode.offlinePin, null, null, null);
      AppLogger.info('AdminPin', 'Logs dashboard opened with the offline PIN');
      return null;
    }

    _pinFailures++;
    AppLogger.warn('AdminPinFailed', 'Wrong offline PIN ($_pinFailures of $_maxPinFailures)');
    if (_pinFailures >= _maxPinFailures) {
      _pinFailures = 0;
      _pinLockedUntil = now.add(_pinLockFor);
      return 'Too many wrong PINs. Locked for ${_pinLockFor.inMinutes} minutes.';
    }
    return 'Wrong PIN.';
  }

  static void logout() => current = null;

  static Future<void> _ensurePinStored(LogDB db) async {
    if (await db.getSetting(pinHashKey) == null) {
      await db.setSetting(pinSaltKey, _defaultPinSalt);
      await db.setSetting(pinHashKey, _defaultPinHash);
    }
  }

  /// salt + PIN, then SHA-256 repeated [pinRounds] times; hex result.
  static String hashPin(String salt, String pin) {
    List<int> bytes = utf8.encode(salt + pin);
    for (var i = 0; i < pinRounds; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @visibleForTesting
  static AdminSession testSession({required bool online}) => online
      ? const AdminSession._(AdminMode.online, 'MX1576', 'Test Admin', 'x')
      : const AdminSession._(AdminMode.offlinePin, null, null, null);

  @visibleForTesting
  static void resetForTest() {
    current = null;
    _pinFailures = 0;
    _pinLockedUntil = null;
  }
}

// Runs in a background isolate so the screen does not freeze while hashing.
String _hashPinIsolate(List<String> args) => AdminService.hashPin(args[0], args[1]);
