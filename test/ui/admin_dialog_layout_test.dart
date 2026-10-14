import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/view/admin/admin_login_dialog.dart';

/// EDA52-sized screen (360 x 640 logical), keyboard open/closed, normal and
/// large system font, with an error message showing.
void main() {
  Future<void> openDialog(WidgetTester tester,
      {required double keyboard, required double fontScale}) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 2.0);
    tester.platformDispatcher.textScaleFactorTestValue = fontScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox())));
    AdminLoginDialog.show();
    await tester.pumpAndSettle();
  }

  for (final keyboard in [0.0, 300.0]) {
    for (final fontScale in [1.0, 1.3, 1.6]) {
      testWidgets('fits: keyboard ${keyboard.toInt()}, font x$fontScale', (tester) async {
        await openDialog(tester, keyboard: keyboard, fontScale: fontScale);
        expect(tester.takeException(), isNull, reason: 'login form');

        // Show an error message (no server configured in tests → error text)
        await tester.enterText(find.byType(TextField).at(0), 'MX1576');
        await tester.enterText(find.byType(TextField).at(1), 'x');
        await tester.tap(find.text('Login'));
        await tester.pump();
        // let the (fake) network call finish, then settle the UI
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
        await tester.pumpAndSettle();
        expect(find.textContaining('offline PIN'), findsWidgets);
        expect(tester.takeException(), isNull, reason: 'login form + error');

        await tester.tap(find.text('No connection? Use offline PIN'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'PIN form');
      });
    }
  }
}
