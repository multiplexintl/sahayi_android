import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/controller/login_controller.dart';
import 'package:sahayi_android/helper/custom_colors.dart';
import 'package:sahayi_android/helper/custom_widget.dart';
import 'package:sahayi_android/widgets/button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var con = Get.put(LoginController());
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: CustomColors.scaffoldColor,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: SizedBox(
                height: 100,
                width: 100,
                child: Image.asset("assets/images/helper_1.png"),
              ),
            ),
            SizedBox(height: 50),
            SizedBox(
              height: 79,
              width: context.width - 100,
              child: TextFormField(
                controller: con.idController,
                onChanged: (value) {
                  con.idController.text = value.toUpperCase();
                },
                decoration: CustomWidget()
                    .inputDecoration(context: context, labelText: "Emp ID"),
              ),
            ),
            SizedBox(
              height: 79,
              width: context.width - 100,
              child: Obx(() => TextFormField(
                    controller: con.pwdController,
                    obscureText: con.isPasswordVisible.value,
                    decoration: CustomWidget()
                        .inputDecoration(
                            context: context, labelText: "Password")
                        .copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(con.isPasswordVisible.value
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => con.isPasswordVisible.toggle(),
                          ),
                        ),
                  )),
            ),
            Obx(
              () => ButtonWidget(
                title: "Login",
                width: 250,
                height: 48,
                onPressed: con.isLoading.value
                    ? null
                    : () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        con.getEmployee();
                      },
                child: con.isLoading.value
                    ? SizedBox(
                        height: 25,
                        width: 25,
                        child: CircularProgressIndicator.adaptive(),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
