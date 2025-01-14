import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/connectivity_controller.dart';

class CustomWidget {
  InputDecoration inputDecoration(
      {required BuildContext context, String? labelText, double? radius}) {
    return InputDecoration(
      labelText: labelText,
      contentPadding:
          const EdgeInsets.only(left: 21, right: 15, top: 15, bottom: 15),
      filled: true,
      fillColor: Colors.white,
      labelStyle: Theme.of(context).textTheme.labelLarge?.merge(const TextStyle(
            letterSpacing: 1.2,
          )),
      floatingLabelStyle:
          Theme.of(context).textTheme.labelLarge?.merge(const TextStyle(
                letterSpacing: 1.2,
              )),
      enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.all(Radius.circular(radius ?? 15))),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.all(Radius.circular(radius ?? 15)),
      ),
      focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.all(Radius.circular(radius ?? 15))),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
        borderRadius: BorderRadius.all(
          Radius.circular(radius ?? 15),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.all(
          Radius.circular(radius ?? 15),
        ),
      ),
      errorStyle: Theme.of(context).textTheme.bodySmall?.merge(
            const TextStyle(
              color: Colors.red,
              height: 0.5,
            ),
          ),
    );
  }

  static AppBar customAppBar(
    String title, {
    bool? back,
    bool? connectivity = true,
    void Function()? logout,
  }) {
    var connecCon = Get.find<ConnectivityController>();
    return AppBar(
      automaticallyImplyLeading: back ?? false,
      title: Text(title),
      backgroundColor: Colors.blue,
      leading: back == true
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: back == true
                  ? () {
                      Get.back();
                    }
                  : null,
            )
          : null,
      centerTitle: true,
      actions: [
        if (connectivity == true)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Obx(() => Container(
                  height: 25,
                  width: 25,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    color: connecCon.isInternetConnected.value
                        ? Colors.green
                        : Colors.red,
                  ),
                )),
          ),
        if (connectivity == false)
          Padding(
            padding: const EdgeInsets.only(right: 10, bottom: 0),
            child: GestureDetector(
              onTap: logout,
              child: SizedBox(
                height: 40,
                width: 40,
                child: Icon(
                  Icons.logout,
                  color: Colors.black,
                  size: 25,
                ),
              ),
            ),
          )
      ],
    );
  }

  // custom snack bar
  static Future<SnackbarController> customSnackBar(
      {required String title,
      required String message,
      Color? textColor,
      Color? backgroundColor,
      int? duration}) async {
    Get.closeAllSnackbars();
    return Get.snackbar(
      title, message,
      backgroundColor: backgroundColor ?? Colors.green,
      colorText: textColor ?? Colors.white,
      isDismissible: true,
      snackPosition: SnackPosition.TOP,
      animationDuration: const Duration(milliseconds: 500),
      duration: Duration(seconds: duration ?? 3),
      margin: const EdgeInsets.only(bottom: 15, left: 15, right: 15),
      snackStyle: SnackStyle.FLOATING,
      // boxShadows: [
      //   BoxShadow(
      //       color: textColor.withOpacity(0.5),
      //       spreadRadius: 3,
      //       blurRadius: 7,
      //       offset: const Offset(0, 10)),
      // ],
      borderColor: Colors.white,
      borderWidth: 1,
      // titleText: Text(
      //   title,
      //   style: const TextStyle(
      //     color: Colors.white,
      //     fontWeight: FontWeight.w700,
      //     fontFamily: "Gotham",
      //     fontStyle: FontStyle.normal,
      //     fontSize: 18,
      //   ),
      // ),
      // messageText: Text(
      //   message,
      //   style: const TextStyle(
      //     color: Colors.white,
      //     fontWeight: FontWeight.w500,
      //     fontFamily: "Gotham",
      //     fontStyle: FontStyle.normal,
      //     fontSize: 16,
      //   ),
      // )
    );
  }

  static Future<dynamic> customDialogue({
    String? okText,
    required String title,
    required String subTitle,
    required void Function()? onPressed,
    void Function()? onPressedBack,
  }) {
    return Get.dialog(AlertDialog(
      title: Center(
          child: Text(
        title,
      )),
      alignment: Alignment.center,
      actionsAlignment: MainAxisAlignment.center,
      content: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subTitle),
            // CustomWidgets.gap(h: 10),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            onPressedBack != null
                ? Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        fixedSize: const Size(double.infinity, 40),
                      ),
                      onPressed: onPressedBack,
                      child: const Text(
                        "Back",
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : SizedBox(),
            SizedBox(width: onPressedBack != null ? 5 : 0),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  fixedSize: const Size(double.infinity, 40),
                ),
                onPressed: onPressed,
                child: Text(
                  okText ?? "Confirm",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ));
  }
}
