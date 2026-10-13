import 'dart:developer';

import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/user.dart';
import '../routes.dart';
import 'connectivity_controller.dart';
import '../service/app_logger.dart';

class HomeController extends GetxController {
  var user = Rx<User>(User());

  var version = Rxn<String>();
  var buildNumber = Rxn<String>();

  @override
  void onInit() async {
    super.onInit();
    user.value = Get.arguments;
    Get.put(ConnectivityController());
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    version.value = packageInfo.version;
    buildNumber.value = packageInfo.buildNumber;
  }

  void logOut() async {
    const String userKey = 'user'; // Key for storing user data
    const String sessionKey = 'sessionTime'; // Key for session time
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(userKey);
    await prefs.remove(sessionKey);
    user.value = User();
    AppLogger.info('Logout', 'User logged out');
    AppLogger.setUser(null);
    AppLogger.setCompany(null);
    log("Session cleared successfully.");
    Get.offNamed(RouteLinks.login);
  }
}
