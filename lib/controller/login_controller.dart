import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/helper/custom_widget.dart';
import 'package:sahayi_android/repo/login_repo.dart';
import 'package:sahayi_android/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/user.dart';

class LoginController extends GetxController {
  TextEditingController idController = TextEditingController();
  TextEditingController pwdController = TextEditingController();
  static const String _userKey = 'user'; // Key for storing user data
  static const String _sessionKey = 'sessionTime'; // Key for session time

  var isPasswordVisible = false.obs;

  var currentUser = User();

  var isLoading = false.obs;

  void login() async {}

  // get employee
  void getEmployee() async {
    isLoading.value = true;
    var res = await LoginRepo()
        .getEmployee(empId: idController.text, pwd: pwdController.text);
    res.fold(
      (error) {
        CustomWidget.customSnackBar(
            title: "Error!!", message: error, backgroundColor: Colors.red);
      },
      (user) {
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
