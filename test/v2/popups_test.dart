import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/helper/custom_widget.dart';
import 'package:sahayi_android/service/update_service.dart';
import 'package:sahayi_android/theme/theme_service.dart';
import 'package:sahayi_android/ui/ui.dart';
import 'package:sahayi_android/view/update/update_dialog.dart';
import 'package:sahayi_android/widgets/button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contrast_test.dart' show contrast;
import 'test_app.dart';

void eda52(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() => bothThemes(_tests);

void _tests() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('top bar stands apart from the page (card colour + line)', (tester) async {
    eda52(tester);
    await tester.pumpWidget(testApp(
      home: const Scaffold(appBar: AppTopBar(title: 'INV-1', subtitle: 'Customer'), body: SizedBox()),
    ));
    final ctx = tester.element(find.text('INV-1'));
    final c = ctx.c;
    final bar = tester.widget<Material>(
        find.ancestor(of: find.text('INV-1'), matching: find.byType(Material)).first);
    expect(bar.color, c.surface);
    expect(bar.color, isNot(c.background));
    expect((bar.shape as Border).bottom.color, c.border);
    expect(contrast(c.text, c.surface), greaterThan(7));
  });

  testWidgets('controller popup (customDialogue): themed, readable, buttons work', (tester) async {
    eda52(tester);
    var ok = 0, back = 0;
    await tester.pumpWidget(testApp(home: const Scaffold(body: SizedBox())));
    CustomWidget.customDialogue(
      title: 'Invoice exists',
      subTitle: 'Overwrite the local copy?',
      okText: 'Overwrite',
      buttonColor: Colors.red,
      onPressed: () => ok++,
      onPressedBack: () => back++,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final ctx = tester.element(find.text('Overwrite the local copy?'));
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, isNull, reason: 'uses the theme surface, not hard-coded white');
    final text = DefaultTextStyle.of(ctx).style.color ?? Theme.of(ctx).colorScheme.onSurface;
    expect(contrast(text, ctx.c.surface), greaterThan(4.5));
    await tester.tap(find.text('Overwrite'));
    await tester.tap(find.text('Back'));
    expect((ok, back), (1, 1));
  });

  testWidgets('controller toast (customSnackBar): red = error colours', (tester) async {
    eda52(tester);
    await tester.pumpWidget(testApp(home: const Scaffold(body: SizedBox())));
    CustomWidget.customSnackBar(title: 'Error!!', message: 'Wrong barcode', backgroundColor: Colors.red);
    await tester.pump(const Duration(milliseconds: 400));
    final ctx = tester.element(find.text('Wrong barcode'));
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    expect(contrast(ctx.c.dangerText, ctx.c.dangerSoft), greaterThan(4.5));
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });

  testWidgets('Return "Already exist" buttons (ButtonWidget) follow the theme', (tester) async {
    eda52(tester);
    var no = 0;
    await tester.pumpWidget(testApp(
      home: Scaffold(
        body: Row(children: [
          ButtonWidget(width: 120, title: 'No', backgroundColor: Colors.red, onPressed: () => no++),
          ButtonWidget(width: 120, title: 'Continue', backgroundColor: Colors.green, onPressed: () {}),
        ]),
      ),
    ));
    expect(find.byType(AppButton), findsNWidgets(2));
    await tester.tap(find.text('No'));
    expect(no, 1);
  });

  testWidgets('update dialog fits the EDA52 and uses the theme', (tester) async {
    eda52(tester);
    await tester.pumpWidget(testApp(home: Builder(builder: (context) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => UpdateDialog.show(
                context,
                const UpdateInfo(
                    versionCode: 17, versionName: '1.0.17', apkName: 'a.apk', notes: 'Bug fixes and the new design.')),
            child: const Text('open'),
          ),
        ),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
  });

  test('saved theme choice is read at start-up', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
    expect((await ThemeService.init()).mode.value, ThemeMode.dark);
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    expect((await ThemeService.init()).mode.value, ThemeMode.system);
  });
}
