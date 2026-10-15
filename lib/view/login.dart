import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/controller/login_controller.dart';

import '../ui/ui.dart';
import '../widgets/admin_tap_detector.dart';

/// Login (Version 2). Same controller calls as Version 1: the ID is upper-cased
/// while typing, getEmployee() logs in.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final con = Get.put(LoginController());
    return Builder(builder: (context) {
      final c = context.c;
      final t = Theme.of(context).textTheme;

      void submit() {
        FocusManager.instance.primaryFocus?.unfocus();
        con.getEmployee();
      }

      return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          body: SafeArea(
            // Scrolls when the keyboard takes space; centred otherwise.
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(height: Space.lg),
                    Image.asset('assets/images/launch_icon.png', width: 140, height: 140),
                    Text('Sahayi', style: t.displaySmall),
                    const SizedBox(height: 2),
                    Text('Warehouse checking made simple', style: t.bodySmall),
                    const SizedBox(height: Space.xl),
                    AppCard(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        AppTextField(
                          label: 'Employee ID',
                          hint: 'e.g. MX1576',
                          controller: con.idController,
                          prefixIcon: Icons.badge_outlined,
                          textInputAction: TextInputAction.next,
                          onChanged: (value) => con.idController.text = value.toUpperCase(),
                        ),
                        const SizedBox(height: Space.md),
                        Obx(() => AppTextField(
                              label: 'Password',
                              controller: con.pwdController,
                              prefixIcon: Icons.lock_outline_rounded,
                              // Hidden by default; the eye shows it. (Version 1 used this
                              // flag the other way round and showed the password.)
                              obscureText: !con.isPasswordVisible.value,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => con.isLoading.value ? null : submit(),
                              suffix: IconButton(
                                tooltip: con.isPasswordVisible.value ? 'Hide password' : 'Show password',
                                icon: Icon(con.isPasswordVisible.value
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded),
                                onPressed: con.isPasswordVisible.toggle,
                              ),
                            )),
                        const SizedBox(height: Space.lg),
                        Obx(() => AppButton(
                              label: 'Log in',
                              icon: Icons.arrow_forward_rounded,
                              iconAfter: true,
                              loading: con.isLoading.value,
                              onPressed: con.isLoading.value ? null : submit,
                            )),
                      ]),
                    ),
                    const SizedBox(height: Space.lg),
                    // 7 taps on the version opens the hidden admin login
                    AdminTapDetector(
                      child: Obx(() => Text(
                            'v${con.version.value ?? ''} (${con.buildNumber.value ?? ''})',
                            style: t.labelSmall?.copyWith(color: c.faint),
                          )),
                    ),
                    const SizedBox(height: Space.md),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
