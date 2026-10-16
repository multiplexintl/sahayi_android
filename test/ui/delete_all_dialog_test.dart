import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/view/admin/all_devices_tab.dart';

import '../v2/test_app.dart';

void main() => bothThemes(_tests);

void _tests() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<Future<bool?>> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(home: const Scaffold(body: SizedBox())));
    final result = Get.dialog<bool>(const DeleteAllDialog());
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('DELETE ALL: confirm closes cleanly (no "used after disposed" crash)', (tester) async {
    final result = await open(tester);
    final button = find.widgetWithText(ElevatedButton, 'Delete everything');
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'DELETE ALL');
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle(); // runs the whole closing animation

    expect(tester.takeException(), isNull);
    expect(await result, isTrue);
    expect(find.byType(DeleteAllDialog), findsNothing);
  });

  testWidgets('DELETE ALL: wrong words keep the button off; Cancel returns false', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Delete everything')).onPressed,
        isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(await result, isFalse);
  });
}
