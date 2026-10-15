import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sahayi_android/theme/app_theme.dart';

/// Light or dark: which mode the current test runs in (see [bothThemes]).
ThemeMode testThemeMode = ThemeMode.light;

/// The app shell exactly as main.dart builds it: global light + dark theme.
Widget testApp({Widget? home, List<GetPage>? getPages}) => GetMaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: testThemeMode,
      home: home,
      getPages: getPages,
    );

/// Runs every test in [body] twice: once in light mode, once in dark mode.
void bothThemes(void Function() body) {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    group('${mode.name} mode', () {
      setUp(() => testThemeMode = mode);
      body();
    });
  }
}
