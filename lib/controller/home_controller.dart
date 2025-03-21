import 'dart:developer';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/user.dart';
import '../routes.dart';
import 'connectivity_controller.dart';

class HomeController extends GetxController {
  var user = Rx<User>(User());

  @override
  void onInit() {
    user.value = Get.arguments;
    Get.put(ConnectivityController());
    super.onInit();
  }

  void logOut() async {
    const String userKey = 'user'; // Key for storing user data
    const String sessionKey = 'sessionTime'; // Key for session time
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(userKey);
    await prefs.remove(sessionKey);
    user.value = User();
    log("Session cleared successfully.");
    Get.offNamed(RouteLinks.login);
  }
}
