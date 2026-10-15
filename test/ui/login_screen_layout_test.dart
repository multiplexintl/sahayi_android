import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sahayi_android/view/admin/admin_login_dialog.dart';
import 'package:sahayi_android/view/login.dart';
import '../v2/test_app.dart';

/// The real Login screen on an EDA52-sized screen (360 x 640) with the keyboard
/// open, with and without the admin popup on top (the case in the screenshot).
void main() => bothThemes(_tests);

void _tests() {
  for (final fontScale in [1.0, 1.3]) {
    for (final withPopup in [false, true]) {
      testWidgets('login screen fits with keyboard open (font x$fontScale, popup $withPopup)',
          (tester) async {
        tester.view.physicalSize = const Size(720, 1280);
        tester.view.devicePixelRatio = 2.0;
        tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 2.0);
        tester.platformDispatcher.textScaleFactorTestValue = fontScale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        PackageInfo.setMockInitialValues(
            appName: 'Sahayi', packageName: 'x', version: '1.0.15', buildNumber: '15', buildSignature: '');

        await tester.pumpWidget(testApp(home: LoginScreen()));
        await tester.pumpAndSettle();
        if (withPopup) {
          AdminLoginDialog.show();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull); // no "BOTTOM OVERFLOWED BY ..."
        Get.reset();
      });
    }
  }
}
