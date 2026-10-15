import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/ui/ui.dart';
import 'package:sahayi_android/view/design_preview/design_preview.dart';

Widget host(Widget child, {bool dark = false}) => GetMaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(12), child: child))),
    );

void eda52(WidgetTester tester, {double font = 1.0}) {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  tester.platformDispatcher.textScaleFactorTestValue = font;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  group('AppButton', () {
    testWidgets('disabled button shows the reason', (tester) async {
      await tester.pumpWidget(host(const AppButton(label: 'Finalize', disabledLabel: 'Finalize · 24 left', onPressed: null)));
      expect(find.text('Finalize · 24 left'), findsOneWidget);
      expect(find.text('Finalize'), findsNothing);
    });

    testWidgets('loading shows a spinner and blocks taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(AppButton(label: 'Sync', loading: true, onPressed: () => taps++)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(taps, 0);
    });

    testWidgets('tap works when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(AppButton(label: 'Sync', onPressed: () => taps++)));
      await tester.tap(find.text('Sync'));
      expect(taps, 1);
    });
  });

  group('Confirm sheet', () {
    for (final (choice, expected) in [('Delete all', true), ('Cancel', false)]) {
      testWidgets('"$choice" returns $expected', (tester) async {
        await tester.pumpWidget(host(const SizedBox()));
        late Future<bool> result;
        result = showConfirmSheet(title: 'Delete all items?', message: 'Cannot be undone.', confirmLabel: 'Delete all', danger: true);
        await tester.pumpAndSettle();
        await tester.tap(find.text(choice));
        await tester.pumpAndSettle();
        expect(await result, expected);
      });
    }
  });

  testWidgets('select field opens a sheet and picks an item', (tester) async {
    String? picked;
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (context, setState) => AppSelectField<String>(
        label: 'Company',
        placeholder: 'Select company',
        value: picked,
        items: const ['EPIC01', 'EPIC02'],
        itemLabel: (s) => s,
        onChanged: (v) => setState(() => picked = v),
      ),
    )));
    await tester.tap(find.text('Select company'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EPIC02'));
    await tester.pumpAndSettle();
    expect(picked, 'EPIC02');
    expect(find.text('EPIC02'), findsOneWidget);
  });

  testWidgets('item card shows state as a word, not only colour', (tester) async {
    await tester.pumpWidget(host(const Column(children: [
      ItemCard(title: 'A', quantity: '1 / 2', state: ItemState.active),
      ItemCard(title: 'B', quantity: '2 / 2', state: ItemState.done),
      ItemCard(title: 'C', quantity: '0 / 2', state: ItemState.todo),
    ])));
    expect(find.text('Scanning'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('To do'), findsOneWidget);
  });

  test('initials', () {
    expect(InitialsAvatar.initialsOf('Amjadh Changanakattil'), 'AC');
    expect(InitialsAvatar.initialsOf('Rashid'), 'R');
    expect(InitialsAvatar.initialsOf('  '), '?');
  });

  test('bundled font files exist', () {
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      expect(File('assets/fonts/plus_jakarta_sans/PlusJakartaSans-$w.ttf').existsSync(), isTrue, reason: w);
    }
  });

  group('Design preview on an EDA52 screen', () {
    for (final dark in [false, true]) {
      for (final font in [1.0, 1.3]) {
        testWidgets('${dark ? 'dark' : 'light'}, font x$font: whole page fits, no overflow', (tester) async {
          eda52(tester, font: font);
          await tester.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const DesignPreviewScreen()));
          await tester.pumpAndSettle();
          if (dark) {
            await tester.tap(find.byTooltip('Switch light or dark'));
            await tester.pumpAndSettle();
          }
          // Scroll through the whole page; any overflow throws.
          for (var i = 0; i < 12; i++) {
            await tester.drag(find.byType(ListView).first, const Offset(0, -500));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          expect(find.text('Feedback'.toUpperCase()), findsOneWidget);
        });
      }
    }
  });
}
