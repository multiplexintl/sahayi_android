import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityController extends GetxController {
  var isInternetConnected = false.obs;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  Future<void> _init() async {
    // Check current state immediately
    isInternetConnected.value = await _hasInternet();

    // Listen for network changes and re-verify
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      final hasNetwork = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);

      if (hasNetwork) {
        isInternetConnected.value = await _hasInternet();
      } else {
        isInternetConnected.value = false;
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
      return false;
    } on TimeoutException catch (e) {
      log('No internet (Timeout): $e');
      return false;
    }
  }

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
