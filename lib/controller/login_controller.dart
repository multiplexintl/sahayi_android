import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sahayi_android/helper/custom_widget.dart';
import 'package:sahayi_android/repo/login_repo.dart';
import 'package:sahayi_android/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/user.dart';
import '../service/app_logger.dart';

class LoginController extends GetxController {
  TextEditingController idController = TextEditingController();
  TextEditingController pwdController = TextEditingController();
  static const String _userKey = 'user'; // Key for storing user data
  static const String _sessionKey = 'sessionTime'; // Key for session time

  var isPasswordVisible = false.obs;

  var currentUser = User();

  var isLoading = false.obs;
  var version = Rxn<String>();
  var buildNumber = Rxn<String>();

  @override
  void onInit() async {
    super.onInit();
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    version.value = packageInfo.version;
    buildNumber.value = packageInfo.buildNumber;
  }

  void login() async {}

  // get employee
  void getEmployee() async {
    isLoading.value = true;
    AppLogger.info('Login', 'Login attempt for ${idController.text}');
    var res = await LoginRepo()
        .getEmployee(empId: idController.text, pwd: pwdController.text);
    res.fold(
      (error) {
        AppLogger.warn('LoginFailed', 'Login failed for ${idController.text}: $error');
        CustomWidget.customSnackBar(
            title: "Error!!", message: error, backgroundColor: Colors.red);
      },
      (user) {
        AppLogger.setUser(user.empID);
        AppLogger.setCompany(user.company);
        AppLogger.info('LoginOk', 'Logged in as ${user.empID} (${user.empName})');
        currentUser = user;
        isLoading.value = false;
        saveUserSession(user).then((val) {
          Get.toNamed(RouteLinks.home, arguments: user);
        });

        log(currentUser.toString());
      },
    );
    isLoading.value = false;
  }

  Future<void> saveUserSession(User user) async {
    final prefs = await SharedPreferences.getInstance();

    // Convert user to JSON and save
    String userJson = jsonEncode(user.toJson());
    await prefs.setString(_userKey, userJson);

    // Save session timestamp
    await prefs.setInt(_sessionKey, DateTime.now().millisecondsSinceEpoch);
    currentUser = user;
    log("User and session stored successfully.");
  }
}
