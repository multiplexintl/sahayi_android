import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:sahayi_android/controller/home_controller.dart';
import 'package:sahayi_android/model/user.dart';

class ConnectivityController extends GetxController {
  var isInternetConnected =
      false.obs; // True only if internet and API both succeed
  var lastApiCallSuccess = false.obs;

  final Connectivity _connectivity = Connectivity();

  var user = User();

  @override
  void onInit() async {
    super.onInit();
    user = HomeController().user.value;
    await _monitorConnectivity();
  }

  /// Monitor real-time internet connectivity and API status
  Future<void> _monitorConnectivity() async {
    _connectivity.onConnectivityChanged.listen((results) async {
      // Check if any connection is available in the list
      final hasInternet = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);

      // Check both internet and API success before setting the flag
      if (hasInternet) {
        bool apiCheck = await _testApiCall();
        isInternetConnected.value = apiCheck;
      } else {
        isInternetConnected.value = false;
      }

      // Show feedback if disconnected
      if (!isInternetConnected.value) {
        Get.snackbar("No Internet", "You are offline or API failed.",
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    });
  }

  /// Check API success along with connectivity
  Future<bool> _testApiCall() async {
    try {
      final response = await http
          .get(Uri.parse('https://jsonplaceholder.typicode.com/posts/1'));
      return response.statusCode == 200;
    } catch (e) {
      log("API Test Failed: $e");
      return false;
    }
  }

  /// Generic API Call Method with Internet + API Check
  Future<bool> makeApiCall({required String url}) async {
    if (!isInternetConnected.value) {
      Get.snackbar("No Internet", "Please check your connection.",
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        lastApiCallSuccess.value = true;
        isInternetConnected.value =
            true; // Confirm API success and connectivity
        return true;
      } else {
        lastApiCallSuccess.value = false;
        isInternetConnected.value = false;
        Get.snackbar("API Error", "Failed to fetch data from the server.",
            backgroundColor: Colors.orange, colorText: Colors.white);
        return false;
      }
    } catch (e) {
      lastApiCallSuccess.value = false;
      isInternetConnected.value = false;
      Get.snackbar("Error", "An error occurred: $e",
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }
}
