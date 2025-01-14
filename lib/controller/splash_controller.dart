import 'dart:convert';
import 'dart:developer';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sahayi_android/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/user.dart';

class SplashController extends GetxController {
  static const String _userKey = 'user'; // Key for storing user data
  static const String _sessionKey = 'sessionTime'; // Key for session time
  static const int _sessionDuration = 12; // Session validity in hours
  var currentUser = Rxn<User>();
  @override
  void onInit() async {
    super.onInit();
    await getStoragePermission().then((granted) async {
      if (granted) {
        await getCurrentUser();
      } else {
        log("Permission Denied");
        Get.snackbar("Permission Required", "Storage permission is required.");
      }
    });
  }

  Future<bool> getStoragePermission() async {
    bool storagePermissionStatus;
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    if (deviceInfo.version.sdkInt >= 30) {
      storagePermissionStatus =
          await Permission.manageExternalStorage.request().isGranted;
    } else {
      storagePermissionStatus = await Permission.storage.request().isGranted;
    }
    log(storagePermissionStatus.toString());
    return storagePermissionStatus;
  }

  Future<void> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString(_userKey);
    final int? lastSessionTime = prefs.getInt(_sessionKey);

    if (userJson != null && lastSessionTime != null) {
      final DateTime lastLoginTime =
          DateTime.fromMillisecondsSinceEpoch(lastSessionTime);
      final DateTime currentTime = DateTime.now();
      final int difference = currentTime.difference(lastLoginTime).inHours;

      if (difference < _sessionDuration) {
        currentUser.value = User.fromJson(jsonDecode(userJson));
        log("Auto-logged in as: ${currentUser.value?.empName}");
        Get.offNamed(RouteLinks.home, arguments: currentUser.value);
      } else {
        log("Session expired, redirecting to login.");
        await clearSession();
        Get.offNamed(RouteLinks.login);
      }
    } else {
      log("No user found, redirecting to login.");
      Get.offNamed(RouteLinks.login);
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_sessionKey);
    currentUser.value = null;
    log("Session cleared successfully.");
  }
}
