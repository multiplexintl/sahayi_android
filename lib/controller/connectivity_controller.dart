import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../service/app_logger.dart';

class ConnectivityController extends GetxController {
  var isInternetConnected = false.obs;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;

  /// When the connection was lost (null while online). Going offline is not
  /// saved; one "Offline" row is saved when it comes back, with the duration.
  DateTime? _offlineSince;
  String _lastNetwork = '';

  @override
  void onInit() {
    super.onInit();
    ever<bool>(isInternetConnected, _trackOffline);
    _init();
  }

  void _trackOffline(bool online) {
    final now = DateTime.now();
    if (!online) {
      _offlineSince ??= now;
    } else if (_offlineSince != null) {
      AppLogger.warn('Offline', offlineMessage(_offlineSince!, now, _lastNetwork));
      _offlineSince = null;
    }
  }

  /// e.g. "Offline 12:31 → 12:44 (13 min), back on wifi"
  static String offlineMessage(DateTime from, DateTime to, String network) {
    String hm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final d = to.difference(from);
    final length = d.inMinutes >= 1 ? '${d.inMinutes} min' : '${d.inSeconds} s';
    final day = from.day == to.day ? '' : ' (from ${from.day}/${from.month})';
    return 'Offline ${hm(from)} → ${hm(to)}$day ($length)'
        '${network.isEmpty ? '' : ', back on $network'}';
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  Future<void> _init() async {
    // Check current state immediately
    final initial = await _connectivity.checkConnectivity();
    _lastNetwork = _names(initial);
    isInternetConnected.value = await _hasInternet();
    if (!isInternetConnected.value) _offlineSince ??= DateTime.now();
    AppLogger.info('Network',
        'Start: ${_names(initial)}, internet check ${isInternetConnected.value ? 'OK' : 'FAILED'}');

    // Listen for network changes and re-verify
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      final hasNetwork = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);
      _lastNetwork = _names(results);

      if (hasNetwork) {
        isInternetConnected.value = await _hasInternet();
      } else {
        isInternetConnected.value = false;
      }

      final text =
          'Changed to ${_names(results)}, internet check ${isInternetConnected.value ? 'OK' : 'FAILED'}';
      if (isInternetConnected.value) {
        AppLogger.info('Network', text);
      } else {
        AppLogger.warn('Network', text);
      }

      if (!isInternetConnected.value) {
        Get.snackbar(
          "No Internet",
          "You are offline. Please check your connection.",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    });
  }

  /// Verifies actual internet access by doing a DNS lookup on a reliable host.
  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException catch (e) {
      log('No internet (SocketException): $e');
      AppLogger.warn('NetworkCheck', 'google.com lookup failed: $e');
      return false;
    } on TimeoutException catch (e) {
      log('No internet (Timeout): $e');
      AppLogger.warn('NetworkCheck', 'google.com lookup timed out after 5s');
      return false;
    }
  }

  static String _names(List<ConnectivityResult> results) => results.isEmpty
      ? 'none'
      : results.map((r) => r.name).join('+');

  /// Call this before any network operation to guard against offline state.
  Future<bool> checkConnectivity() async {
    isInternetConnected.value = await _hasInternet();
    if (!isInternetConnected.value) {
      Get.snackbar(
        "No Internet",
        "Please check your connection.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    return isInternetConnected.value;
  }
}
